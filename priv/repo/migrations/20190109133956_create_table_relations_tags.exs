defmodule TdLm.Repo.Migrations.CreateTableRelationsTags do
  use Ecto.Migration

  def up do
    create table(:relations_tags, primary_key: false) do
      add(:relation_id, references(:relations))
      add(:tag_id, references(:tags))
    end

    execute("""
    insert into relations_tags(relation_id, tag_id) 
    select distinct r.id, s.id
    from relations r, tags s
    where r.relation_type = s.value->>'type'
    """)

    create(index(:relations_tags, [:relation_id]))
    create(index(:relations_tags, [:tag_id]))
  end

  def down do
    drop(table(:relations_tags))
  end
end
