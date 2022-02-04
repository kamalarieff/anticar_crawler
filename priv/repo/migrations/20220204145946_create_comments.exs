defmodule AnticarCrawler.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments) do
      add :body, :text
      add :permalink, :text

      timestamps()
    end

  end
end
