defmodule TdLm.Repo.Migrations.CreateRelations do
  use Ecto.Migration

  def change do
    create table(:relations) do
      add :relation_type, :string
      add :source_id, :string
      add :source_type, :string
      add :target_id, :string
      add :target_type, :string

      timestamps()
    end

  end
end
