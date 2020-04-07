defmodule TdLm.Repo.Migrations.RenameResourceFields do
  use Ecto.Migration

  def change do
    rename(table(:resource_fields), to: table(:resource_links))
  end
end
