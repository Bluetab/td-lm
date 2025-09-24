defmodule TdLm.Repo.Migrations.AddStatusAtRelations do
  use Ecto.Migration

  def change do
    alter table(:relations) do
      add(:status, :string, null: true, default: nil)
    end
  end
end
