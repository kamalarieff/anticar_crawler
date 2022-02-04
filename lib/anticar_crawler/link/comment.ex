defmodule AnticarCrawler.Link.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :body, :string
    field :permalink, :string

    timestamps()
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :permalink])
    |> validate_required([:body, :permalink])
  end
end
