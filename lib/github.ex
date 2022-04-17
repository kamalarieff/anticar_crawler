defmodule GitHub do
  use Tesla

  # plug Tesla.Middleware.BaseUrl, "https://api.github.com"
  plug(Tesla.Middleware.BaseUrl, "https://www.reddit.com")
  # plug Tesla.Middleware.Headers, [{"authorization", "token xyz"}]
  plug(Tesla.Middleware.JSON)

  def user_repos(after_id) do
    get("https://www.reddit.com/r/fuckcars/top.json?t=day&limit=100&after=t3_" <> after_id)
  end

  # TODO: rename this function
  # this returns the posts
  def user_repos() do
    # get("/users/" <> login <> "/repos")
    get("https://www.reddit.com/r/fuckcars/top.json?t=day&limit=2")
  end

  def fetch_all_comments({:ok, %{body: body}}) do
    body["data"]["children"]
    |> Enum.map(fn data -> data["data"]["id"] end)
    |> Enum.map(fn id ->
      Task.async(fn ->
        {:ok, response} = get("https://www.reddit.com/r/fuckcars/comments/" <> id <> ".json")
        # {:ok, response} = get("https://www.reddit.com/r/fuckcars/comments/u5i2ez.json")
        response.body
      end)
    end)
  end

  def parse_all_comments(%{body: body}) do
    # The first element in this response is the post itself so it's not really useful. The comments start at index 1
    replies = Enum.at(body, 1)

    # need to get the replies recursively
    # It also needs to do something like a binary traversal tree
    replies
    |> get_in(["data", "children"])
    |> Enum.at(1)
    |> get_in(["data", "body"])
  end
end

defmodule Leetcode do
  alias AnticarCrawler.Link

  def recursive_function(curr, title) do
    body =
      curr
      |> get_in(["data", "body"])

    permalink =
      curr
      |> get_in(["data", "permalink"])

    id =
      curr
      |> get_in(["data", "id"])

    try do
      match =
        Regex.match?(
          ~r<https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)>,
          body
        )

      # You can put this in the context
      if match do
        # Link.create_comment(%{
        #   "body" => body,
        #   "permalink" => "https://reddit.com" <> permalink,
        #   "comment_id" => id,
        #   "post_title" => title
        # })
      end
    rescue
      _ -> 'Error!'
    end

    cond do
      get_in(curr, ["data", "replies"]) == "" ->
        nil

      get_in(curr, ["data", "replies"]) == nil ->
        nil

      true ->
        replies =
          get_in(curr, ["data", "replies"])
          |> get_in(["data", "children"])

        for i <- replies do
          recursive_function(i, title)
        end
    end
  end

  def start_recursive(post_and_comments) do
    # need to make this loop more readable
    comments = get_comments(post_and_comments)
    # IO.inspect(comments, label: "comments")
    title = get_title(post_and_comments) # title is an array
    IO.inspect(title, label: "title")
    post = get_post_information(post_and_comments) # post is an array
    IO.inspect(post, label: "post")

    for {entry, index} <- Enum.with_index(comments) do
      # IO.inspect(entry, label: "entry")
      for entry1 <- entry do
        recursive_function(entry1, Enum.at(title, index))
      end
    end
  end

  defp get_comments(post_and_comments) do
    post_and_comments
    |> Enum.map(fn x ->
      # 1 is for comments, 0 is for the post
      replies = Enum.at(x, 1)

      replies
      |> get_in(["data", "children"])

      # |> Enum.at(1) # reddit's data structure is so weird
    end)
  end

  defp get_post_information(post_and_comments) do
    post_and_comments
    |> Enum.map(fn x ->
      # 1 is for comments, 0 is for the post
      replies = Enum.at(x, 0)

      replies
      |> get_in(["data", "children"])
      |> Enum.at(0)
    end)
  end

  defp get_title(comments) do
    comments
    |> Enum.map(fn x ->
      # 1 is for replies, 0 is for the post
      replies = Enum.at(x, 0)

      replies
      |> get_in(["data", "children"])
      |> Enum.at(0)
      |> get_in(["data", "title"])

      # |> Enum.at(1) # reddit's data structure is so weird
    end)
  end
end
