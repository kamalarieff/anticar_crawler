defmodule AnticarCrawlerWeb.PageLive do
  use AnticarCrawlerWeb, :live_view
  alias AnticarCrawler.Link
  alias AnticarCrawler.Link.Comment
  alias Reddit

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
    "GifReversingBot"
  ]

  @blocked_links [
    ~r<(google\.com|goo\.gl)/maps>,
    ~r<maps.app.goo.gl>,
    ~r<earth.google.com>,
    ~r<(fr|en|upload)(\.m)?.wikipedia.org>,
    # Not Just Bikes - I am not a "Cyclist" (and most Dutch people aren't either)
    ~r<\bvMed1qceJ_Q\b>,
    # Not Just Bikes - Why Canadians Can't Bike in the Winter (but Finnish people can)
    ~r<\bUhx-26GfCBU\b>,
    # Climate Town - The Suburbs Are Bleeding America Dry | Climate Town (feat. Not Just Bikes)
    ~r<\bSfsCniN7Nsc\b>,
    # Climate Town - How The Auto Industry Carjacked The American Dream | Climate Town
    ~r<\boOttvpjJvAo\b>,
    # Not Just Bikes - The Ugly, Dangerous, and Inefficient Stroads found all over the US & Canada [ST05]
    ~r<\bORzNZUeUHAM\b>
  ]

  @impl true
  def mount(_params, _session, socket) do
    links = Link.list_comments()
    {:ok, assign(socket, query: "", results: %{}, links: links)}
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
        Link.create_comment(%{
          "body" => body,
          "permalink" => "https://reddit.com" <> permalink,
          "comment_id" => id,
          "post_title" => post["title"],
          "post_id" => post["id"]
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

  @impl true
  def handle_event("trigger-crawler", _args, socket) do
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

    links = Link.list_comments()

    {:noreply,
     socket
     |> assign(links: links)
     |> put_flash(:info, "Fetched successfully!")}
  end

  @impl true
  def handle_event("delete-comment", %{"comment_id" => id}, socket) do
    case Link.delete_comment(%Comment{id: String.to_integer(id)}) do
      {:ok, _} ->
        links = Link.list_comments()
        {:noreply, assign(socket, links: links)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete-all", _args, socket) do
    Link.delete_all_comments()
    links = Link.list_comments()
    {:noreply, assign(socket, links: links)}
  end

  @impl true
  def handle_event("suggest", %{"q" => query}, socket) do
    {:noreply, assign(socket, results: search(query), query: query)}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    case search(query) do
      %{^query => vsn} ->
        {:noreply, redirect(socket, external: "https://hexdocs.pm/#{query}/#{vsn}")}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "No dependencies found matching \"#{query}\"")
         |> assign(results: %{}, query: query)}
    end
  end

  @doc """
  Render HTML string as HTML
  """
  def parse_markdown(body) do
    with {:ok, html, _params} <- Earmark.as_html(body) do
      raw(html)
    else
      _ ->
        body
    end
  end

  defp search(query) do
    if not AnticarCrawlerWeb.Endpoint.config(:code_reloader) do
      raise "action disabled when not in development"
    end

    for {app, desc, vsn} <- Application.started_applications(),
        app = to_string(app),
        String.starts_with?(app, query) and not List.starts_with?(desc, ~c"ERTS"),
        into: %{},
        do: {app, vsn}
  end
end
