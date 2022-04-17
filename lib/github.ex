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
    get("https://www.reddit.com/r/fuckcars/top.json?t=day&limit=100")
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
end

