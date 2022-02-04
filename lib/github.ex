defmodule GitHub do
  use Tesla

  # plug Tesla.Middleware.BaseUrl, "https://api.github.com"
  plug(Tesla.Middleware.BaseUrl, "https://www.reddit.com")
  # plug Tesla.Middleware.Headers, [{"authorization", "token xyz"}]
  plug(Tesla.Middleware.JSON)

  def user_repos(after_id) do
    get("https://www.reddit.com/r/fuckcars/top.json?t=day&limit=100&after=t3_" <> after_id)
  end

  def user_repos() do
    # get("/users/" <> login <> "/repos")
    get("https://www.reddit.com/r/fuckcars/top.json?t=day&limit=100")
  end

  def get_last(response) do
    response.body["data"]["children"]
    |> List.last()
  end

  def get_id(data) do
    data["data"]["id"]
  end

  def fetch_all_comments({:ok, %{body: body}}) do
    body["data"]["children"]
    |> Enum.map(fn data -> data["data"]["id"] end)
    |> Enum.map(fn id ->
      Task.async(fn ->
        {:ok, response} = get("https://www.reddit.com/r/fuckcars/comments/" <> id <> ".json")
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
