defmodule TdLm.Repo.Migrations.CreateNewRelations do
  use Ecto.Migration

  def up do
    create table(:relations) do
      add(:source_id, :bigint)
      add(:source_type, :string)
      add(:target_id, :bigint)
      add(:target_type, :string)
      add(:context, :map)
      add(:deleted_at, :utc_datetime_usec, default: nil, null: true)
      add(:origin, :string, null: true)
      add(:tag_id, references(:tags, on_delete: :nilify_all))

      timestamps(type: :utc_datetime_usec)
    end

    create(
      unique_index(:relations, [:source_id, :source_type, :target_id, :target_type, :tag_id],
        where: "deleted_at IS NOT NULL"
      )
    )

    create(index(:relations, [:tag_id]))
  end

  def down do
    drop(table(:relations))
  end
end
