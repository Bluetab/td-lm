defmodule TdLm.Repo.Migrations.AddColumnToRelationsTable do
  use Ecto.Migration

  def change do
    rename(table(:relations), to: table(:relations_backup))
  end
end
