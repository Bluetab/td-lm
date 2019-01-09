defmodule TdLm.Repo.Migrations.BackUpRelationTypeField do
  use Ecto.Migration

  def up do
    rename table(:relations), :relation_type, to: :relation_type_back_up
  end

  def down do
    rename table(:relations), :relation_type_back_up, to: :relation_type
  end
end
