defmodule TdLm.Repo.Migrations.RenameRelationsTableToRelationsBackupAgain do
  use Ecto.Migration

  def up do
    drop_if_exists(table(:relations_tags))
    drop_if_exists(table(:relations_backup))
    rename(table(:relations), to: table(:relations_backup))

    drop_if_exists(
      unique_index(:relations, [:source_id, :source_type, :target_id, :target_type, :tag_id],
        where: "deleted_at IS NOT NULL"
      )
    )

    drop_if_exists(index(:relations, [:tag_id]))
  end

  def down do
    rename(table(:relations_backup), to: table(:relations))
    create(index(:relations, [:tag_id]))

    create(
      unique_index(:relations, [:source_id, :source_type, :target_id, :target_type, :tag_id],
        where: "deleted_at IS NOT NULL"
      )
    )
  end
end
