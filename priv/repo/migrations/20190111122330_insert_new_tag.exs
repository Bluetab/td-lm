defmodule TdLm.Repo.Migrations.InsertNewTag do
  use Ecto.Migration

  def change do    
    execute("""
    INSERT INTO tags (value, inserted_at, updated_at)
    VALUES ('{"type": "business_concept_to_field_master"}', NOW(), NOW())
    """)
  end
end
