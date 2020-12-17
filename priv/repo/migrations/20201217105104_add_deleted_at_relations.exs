defmodule TdLm.Repo.Migrations.AddDeletedAtRelations do
  use Ecto.Migration

  def up do
    alter table(:relations) do
      add(:deleted_at, :utc_datetime_usec, default: nil, null: true)
    end
  end

  def down do
    alter table(:relations) do
      remove(:deleted_at, :utc_datetime_usec, default: nil, null: true)
    end
  end
end
