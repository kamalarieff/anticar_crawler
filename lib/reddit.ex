defmodule Reddit do
  use Tesla

  plug(Tesla.Middleware.BaseUrl, "https://www.reddit.com")
  plug(Tesla.Middleware.JSON)

  @doc """
  Returns the posts
  """
  def top_posts() do
    get("https://www.reddit.com/r/fuckcars/top.json?t=day&limit=100")
  end

  @doc """
  The way reddit API works is that when you call this endpoint, it will
  return the post information in the response as well.
  """
  def fetch_post_and_comments({:ok, %{body: body}}) do
    body["data"]["children"]
    |> Enum.map(fn data -> data["data"]["id"] end)
    |> Enum.map(fn id ->
      Task.async(fn ->
        {:ok, response} = get("https://www.reddit.com/r/fuckcars/comments/" <> id <> ".json")
        response.body
      end)
    end)
  end

  def get_embed(id) do
    body =
      with {:post_state, post_state} <- {:post_state, PostState.get_by_post_id(id)},
           {:is_post_state_nil, false} <- {:is_post_state_nil, is_nil(post_state)},
           {:body, body} <- {:body, Map.get(post_state, "body")},
           {:is_body_nil, false} <- {:is_body_nil, is_nil(body)} do
        body
      else
        _ ->
          {:ok, %{body: body}} =
            get("https://www.redditmedia.com/r/fuckcars/comments/" <> id <> "?embed=true")

          PostState.update(id, %{"body" => body})
          body
      end

    Phoenix.HTML.raw(body)
  end
end

defmodule PostState do
  use Agent

  def start_link(_opts) do
    initial_value = %{}

    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def value do
    Agent.get(__MODULE__, & &1)
  end

  def get_by_post_id(post_id) do
    Agent.get(__MODULE__, &Map.get(&1, post_id))
  end

  def update(post_id, attrs \\ %{}) do
    Agent.update(__MODULE__, fn state ->
      temp =
        state[post_id]
        |> case do
          nil -> %{}
          _ -> state[post_id]
        end
        |> Map.merge(attrs)

      Map.merge(state, %{post_id => temp})
    end)
  end
end

defmodule CommentState do
  use Agent

  def start_link(_opts) do
    initial_value = %{}

    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def value do
    Agent.get(__MODULE__, & &1)
  end

  def get_by_comment_id(comment_id) do
    Agent.get(__MODULE__, &Map.get(&1, comment_id))
  end

  def update(comment_id, attrs \\ %{}) do
    Agent.update(__MODULE__, fn state ->
      temp =
        state[comment_id]
        |> case do
          nil -> %{}
          _ -> state[comment_id]
        end
        |> Map.merge(attrs)

      Map.merge(state, %{comment_id => temp})
    end)
  end
end

defmodule Reddit.Processor do
  use GenServer
  alias AnticarCrawler.Link

  @post_index 0
  @comments_index 1

  @banned_users [
    "twitterStatus_Bot",
    "autotldr",
    "B0tRank",
    "WikiMobileLinkBot",
    "RepostSleuthBot",
    "Anti-ThisBot-IB",
    "haikusbot",
    "resavr_bot",
    "alphabet_order_bot",
    "ectbot",
    "savevideobot",
    "same_post_bot",
    "Paid-Not-Payed-Bot",
    "same_subreddit_bot",
    "SaveVideo",
    "wikipedia_answer_bot",
    "auddbot",
    "sneakpeekbot",
    "JustAnAlpacaBot",
    "ReverseCaptioningBot",
    "WikiSummarizerBot",
    "sub_doesnt_exist_bot",
    "properu",
    "AutoModerator",
    "RemindMeBot",
    "FatFingerHelperBot",
    "LuckyNumber-Bot",
    "timee_bot",
    "WhyNotCollegeBoard",
    "AmputatorBot",
    "botrickbateman",
    "UkraineWithoutTheBot",
    "gifendore",
    "GifReversingBot",
    "MAGIC_EYE_BOT",
    "stabbot",
    "phonebatterylevelbot",
    "underscorebot"
  ]

  @blocked_links [
    ~r<(google\.(com|ca|de|at|nl|au|ch|uk|pl|ro)|goo\.gl)/maps>,
    ~r<maps.app.goo.gl>,
    ~r<g.page>,
    ~r<earth.google.com>,
    ~r<arcgis.com>,
    ~r<(fr|en|de|sv|upload|nl)(\.m)?.wikipedia.org>,
    # Not Just Bikes - I am not a "Cyclist" (and most Dutch people aren't either)
    ~r<\bvMed1qceJ_Q\b>,
    # Not Just Bikes - Why Canadians Can't Bike in the Winter (but Finnish people can)
    ~r<\bUhx-26GfCBU\b>,
    # Climate Town - The Suburbs Are Bleeding America Dry | Climate Town (feat. Not Just Bikes)
    ~r<\bSfsCniN7Nsc\b>,
    # Climate Town - How The Auto Industry Carjacked The American Dream | Climate Town
    ~r<\boOttvpjJvAo\b>,
    # Not Just Bikes - The Ugly, Dangerous, and Inefficient Stroads found all over the US & Canada [ST05]
    ~r<\bORzNZUeUHAM\b>,
    # CaseyNeistat - Bike Lanes by Casey Neistat
    ~r<\bbzE-IMaegzQ\b>,
    # Not Just Bikes - The Best Country in the World for Drivers
    ~r<\bd8RRE2rDw4k\b>,
    # Not Just Bikes - Cities Aren't Loud: Cars Are Loud
    ~r<\bCTV-wwszGw8\b>,
    # Not Just Bikes - Why Grocery Shopping is Better in Amsterdam
    ~r<\bkYHTzqHIngk\b>,
    # Not Just Bikes - Business Parks Suck (but they don't have to)
    ~r<\bSDXB0CY2tSQ\b>,
    # Not Just Bikes - Suburbia is Subsidized: Here's the Math [ST07]
    ~r<\b7Nw6qyyrTeI\b>,
    # TomSka - I LIKE TRAINS (asdfmovie song)
    ~r<\bhHkKJfcBXcw\b>,
    # 12 best ways to get cars out of cities – ranked by new research
    ~r<\bhttps://theconversation.com/12-best-ways-to-get-cars-out-of-cities-ranked-by-new-research-180642\b>,
    # Climate Town - Who Actually Controls Gas Prices? | Climate Town
    ~r<\bQnBqAzJXVGo\b>,
    # Hoy - The Simpsons - Canyonero
    ~r<\bPI_Jl5WFQkA\b>,
    # Cars Ruin Cities Sticker 10-Pack
    ~r<\bhttps://the-war-on-cars.myshopify.com/products/cars-ruin-cities-sticker-10-pack\b>,
    # Not Just Bikes - There's Something Wrong With Suburbia (The Orange Pill)
    ~r<\bOQE_5MFCekg\b>,
    # Propel - This American Mayor is Creating the Ultimate Biking City
    ~r<\bFlVWv9O0qQ4\b>,
    # Not Just Bikes - The Gym of Life
    ~r<\bKPUlgSRn6e0\b>,
    # Not Just Bikes - Why We Won't Raise Our Kids in Suburbia
    ~r<\boHlpmxLTxpw\b>,
  ]

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(stack) do
    {:ok, stack}
  end

  @impl true
  def handle_cast({:process_comments, pid}, state) do
    tasks = Reddit.top_posts() |> Reddit.fetch_post_and_comments()
    post_and_comments = Task.await_many(tasks, :infinity)
    # comments here include the post and comments thing
    post_and_comments
    |> Enum.map(fn entry ->
      # 0 is for the post, 1 is for comments 
      post = Enum.at(entry, 0)

      post_information =
        post
        |> get_in(["data", "children"])
        |> Enum.at(0)
        |> get_in(["data"])

      entry
      |> Enum.at(1)
      |> get_in(["data", "children"])
      |> Enum.map(fn comment ->
        recursive_comments(comment, post_information)
      end)
    end)

    Process.send(pid, :process_comments_success, [])

    {:noreply, [state]}
  end

  defp recursive_comments(curr, post) do
    body =
      curr
      |> get_in(["data", "body"])

    permalink =
      curr
      |> get_in(["data", "permalink"])

    id =
      curr
      |> get_in(["data", "id"])

    author =
      curr
      |> get_in(["data", "author"])

    try do
      with false <- is_nil(body),
           true <-
             Regex.match?(
               ~r<https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)>,
               body
             ),
           link <-
             Regex.run(
               ~r<https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9(@:%_\+.~#?&//=]*)>,
               body
             )
             |> Enum.at(0),
           false <- Enum.member?(@banned_users, author),
           false <-
             @blocked_links
             |> Enum.map(fn regex ->
               Regex.match?(regex, link)
             end)
             |> Enum.any?() do
        %{"id" => post_id, "link_flair_text" => link_flair_text, "title" => post_title} = post

        is_submitter =
          curr
          |> get_in(["data", "is_submitter"])

        PostState.update(post_id, %{"tag" => link_flair_text})
        CommentState.update(id, %{"is_op" => is_submitter})

        Link.create_comment(%{
          "body" => body,
          "permalink" => "https://reddit.com" <> permalink,
          "comment_id" => id,
          "post_title" => post_title,
          "post_id" => post_id
        })
      end
    rescue
      e -> IO.inspect(e, label: "e")
    end

    cond do
      is_nil(body) ->
        nil

      get_in(curr, ["data", "replies"]) == "" ->
        nil

      get_in(curr, ["data", "replies"]) == nil ->
        nil

      true ->
        replies =
          curr
          |> get_in(["data", "replies"])
          |> get_in(["data", "children"])

        for reply <- replies do
          recursive_comments(reply, post)
        end
    end
  end

  # This will actually build out the comment tree. I think it's a useful data structure but
  # it's not very performant. So please check out the next method of implementation
  defp recursive_new(curr, res) do
    body =
      curr
      |> get_in(["data", "body"])

    res = res ++ [body]

    cond do
      is_nil(body) ->
        res

      get_in(curr, ["data", "replies"]) == "" ->
        res

      get_in(curr, ["data", "replies"]) == nil ->
        res

      true ->
        replies =
          curr
          |> get_in(["data", "replies"])
          |> get_in(["data", "children"])

        for reply <- replies do
          recursive_new(reply, res)
        end
    end
  end
end
