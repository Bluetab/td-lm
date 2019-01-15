defmodule TdLm.Repo.Migrations.UpdateTargetTypeInRelations do
  use Ecto.Migration

  def change do
    execute("""
    UPDATE relations
    SET target_type = 'data_field'
    WHERE target_type = 'field'; 
    """)
  end
end
