defmodule TdLm.Repo.Migrations.AlterTableRelationsTagsCascadeDeletes do
  use Ecto.Migration

  def change do
    alter table(:relations_tags, primary_key: false) do
      modify(:relation_id, references(:relations, on_delete: :delete_all), from: references(:relations))
      modify(:tag_id, references(:tags, on_delete: :delete_all), from: references(:tags))
    end
  end
end
