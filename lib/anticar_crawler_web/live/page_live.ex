defmodule AnticarCrawlerWeb.PageLive do
  use AnticarCrawlerWeb, :live_view
  alias AnticarCrawler.Link
  alias AnticarCrawler.Link.Comment
  alias Reddit
  alias PostState
  alias CommentState

  @impl true
  def mount(_params, _session, socket) do
    links = Link.list_comments() |> group_by_post_id()

    {:ok, assign(socket, query: "", results: %{}, links: links)}
  end

  @impl true
  def handle_event("trigger-crawler", _args, socket) do
    GenServer.cast(Reddit.Processor, {:process_comments, self()})
    notification = %{content: "Fetching...", id: Ecto.UUID.generate()}

    {:noreply, socket |> push_event("notify", notification)}
  end

  @impl true
  def handle_event("undo-deleted-comment", _args, socket) do
    Link.undo_delete_comment()
    links = Link.list_comments() |> group_by_post_id()

    notification = %{
      content: "Successfully undo last deleted comment",
      id: Ecto.UUID.generate()
    }

    {:noreply,
     socket
     |> push_event("notify", notification)
     |> assign(links: links)}
  end

  @impl true
  def handle_event("delete-comment", %{"comment_id" => id}, socket) do
    case Link.delete_comment(%Comment{id: String.to_integer(id)}) do
      {:ok, _} ->
        links = Link.list_comments() |> group_by_post_id()
        {:noreply, assign(socket, links: links)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete-all", _args, socket) do
    Link.delete_all_comments()
    links = Link.list_comments() |> group_by_post_id()
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

  @impl true
  def handle_info(:process_comments_success, socket) do
    links = Link.list_comments() |> group_by_post_id()
    notification = %{content: "Fetched successfully", id: Ecto.UUID.generate()}

    {:noreply,
     socket
     |> push_event("notify", notification)
     |> assign(links: links)
     |> clear_flash(:info)}
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

  @doc """
  Show tags from reddit
  """
  def show_tag(assigns) do
    tag = PostState.get_by_post_id(assigns.post_id)["tag"]

    case is_nil(tag) do
      false ->
        ~H"""
        <span class="badge p-4"><%= tag %></span>
        """

      _ ->
        ~H"""
        """
    end
  end

  @doc """
  Show badge if OP
  """
  def show_op(assigns) do
    is_op = CommentState.get_by_comment_id(assigns.comment_id)["is_op"]

    case is_op do
      true ->
        ~H"""
        <span class="badge badge-info p-4">OP</span>
        """

      _ ->
        ~H"""
        """
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

  defp group_by_post_id(links) do
    Enum.group_by(links, fn x ->
      Map.get(x, :post_id)
    end)
  end
end
