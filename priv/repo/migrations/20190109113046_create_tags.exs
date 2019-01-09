defmodule TdLm.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :value, :map

      timestamps()
    end

  end
end
