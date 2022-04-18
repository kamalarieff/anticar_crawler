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
end

