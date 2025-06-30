defmodule TdLm.Repo.Migrations.AddRelationsOrigin do
  use Ecto.Migration

  def change do
    alter table(:relations) do
      add(:origin, :string, null: true)
    end
  end
end
