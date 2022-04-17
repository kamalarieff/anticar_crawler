defmodule AnticarCrawlerWeb.PageLive do
  use AnticarCrawlerWeb, :live_view
  alias AnticarCrawler.Link
  alias AnticarCrawler.Link.Comment
  alias GitHub
  alias Leetcode

  @impl true
  def mount(_params, _session, socket) do
    links = Link.list_comments()
    {:ok, assign(socket, query: "", results: %{}, links: links)}
  end

  @impl true
  def handle_event("trigger-crawler", _args, socket) do
    tasks = GitHub.user_repos() |> GitHub.fetch_all_comments()
    comments = Task.await_many(tasks, :infinity)
    Leetcode.start_recursive(comments)
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
