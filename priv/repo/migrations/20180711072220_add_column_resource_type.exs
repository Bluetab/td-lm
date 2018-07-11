defmodule TdLm.Repo.Migrations.AddColumnResourceType do
  use Ecto.Migration

  def change do
    alter table(:resource_fields) do
      add :resource_type, :string
    end
  end
end
