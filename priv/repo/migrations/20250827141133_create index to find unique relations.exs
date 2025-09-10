defmodule :"Elixir.TdLm.Repo.Migrations.Create index to find unique relations" do
  use Ecto.Migration

  def up do
    execute("""
    CREATE UNIQUE INDEX relations_unique_idx
    ON relations (
      source_id,
      source_type,
      target_id,
      target_type,
      COALESCE(tag_id, -1)
    )
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS relations_unique_idx")
  end
end
