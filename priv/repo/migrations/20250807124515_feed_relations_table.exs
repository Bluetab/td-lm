defmodule TdLm.Repo.Migrations.FeedRelationsTable do
  use Ecto.Migration

  import Ecto.Query

  alias TdLm.Repo

  def up do
    unique_relation_ids =
      from(r in "relations_backup")
      |> join(:left, [r], rt in "relations_tags", on: rt.relation_id == r.id)
      |> group_by([r, rt], [
        r.source_id,
        r.source_type,
        r.target_id,
        r.target_type,
        r.deleted_at,
        rt.tag_id
      ])
      |> select([r, rt], %{id: max(r.id), tag_id: rt.tag_id})

    query =
      from(r in "relations_backup")
      |> join(:inner, [r, rb], rb in subquery(unique_relation_ids), on: r.id == rb.id)
      |> select([r, rb], %{
        source_id: r.source_id,
        source_type: r.source_type,
        target_id: r.target_id,
        target_type: r.target_type,
        context: r.context,
        origin: r.origin,
        deleted_at: r.deleted_at,
        updated_at: r.updated_at,
        inserted_at: r.inserted_at,
        tag_id: rb.tag_id
      })

    Repo.insert_all("relations", query)
  end

  def down do
    execute("DELETE FROM relations")
  end
end
