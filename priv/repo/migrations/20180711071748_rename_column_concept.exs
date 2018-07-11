defmodule TdLm.Repo.Migrations.RenameColumnConcept do
  use Ecto.Migration

  def change do
    rename table(:resource_fields), :concept, to: :resource_id
  end
end
