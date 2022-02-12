defmodule AnticarCrawler.Repo.Migrations.AddFieldsToComments do
  use Ecto.Migration

  def change do
    alter table(:comments) do
      add :comment_id, :string, size: 50
      add :post_title, :text
      add :status, :text, default: "active"
    end

    create index(:comments, [:comment_id], name: :unique_comment_id, unique: true)
    create constraint(:comments, :status_must_be_valid_value, check: "status IN ('active','deleted')")
  end
end
