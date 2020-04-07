defmodule TdLm.Repo.Migrations.RenameTableConceptFields do
  use Ecto.Migration

  def change do
    rename(table(:concept_fields), to: table(:resource_fields))
  end
end
