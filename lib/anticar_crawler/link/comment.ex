defmodule AnticarCrawler.Link.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :body, :string
    field :permalink, :string
    field :comment_id, :string
    field :post_title, :string
    field :post_id, :string
    field :status, :string

    timestamps()
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :permalink, :comment_id, :post_id, :post_title, :status])
    |> validate_required([:body, :permalink, :comment_id, :post_id, :post_title])
    |> unique_constraint([:comment_id])
    |> check_constraint(:status, name: :status_must_be_valid_value)
  end

  def delete_changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :permalink, :comment_id, :post_title, :status])
    |> check_constraint(:status, name: :status_must_be_valid_value)
  end
end
