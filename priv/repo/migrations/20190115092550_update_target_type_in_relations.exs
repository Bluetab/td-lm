defmodule TdLm.Repo.Migrations.UpdateTargetTypeInRelations do
  use Ecto.Migration

  def change do
    execute("update relations set target_type = 'data_field' where target_type = 'field'", "")
  end
end
