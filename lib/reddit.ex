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

  def update(post_id, %{"tag" => tag, "is_op" => is_op}) do
    Agent.update(__MODULE__, fn state ->
      Map.merge(state, %{post_id => %{"tag" => tag, "is_op" => is_op}})
    end)
  end
end
