defmodule AnticarCrawler.Repo.Migrations.AddPostIdToComments do
  use Ecto.Migration

  def change do
    alter table(:comments) do
      add :post_id, :string, size: 50
    end

    create index(:comments, [:post_id])
  end
end
