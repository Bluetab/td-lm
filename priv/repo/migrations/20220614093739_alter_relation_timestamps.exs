defmodule TdLm.Repo.Migrations.AlterRelationTimestamps do
  use Ecto.Migration

  def change do
    alter table("relations") do
      modify(:inserted_at, :utc_datetime_usec, from: :naive_datetime)
      modify(:updated_at, :utc_datetime_usec, from: :naive_datetime)
    end
  end
end
