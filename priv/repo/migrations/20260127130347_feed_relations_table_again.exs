defmodule TdLm.Repo.Migrations.FeedRelationsTableAgain do
  use Ecto.Migration

  import Ecto.Query

  alias TdLm.Repo

  def up do
    unique_relation_ids =
      from(r in "relations_backup")
      |> group_by([r], [
        r.source_id,
        r.source_type,
        r.target_id,
        r.target_type,
        r.deleted_at,
        r.tag_id
      ])
      |> select([r, rt], %{id: max(r.id)})

    query =
      from(r in "relations_backup")
      |> join(:inner, [r], s in subquery(unique_relation_ids), on: r.id == s.id)
      |> select([r, _s], %{
        source_id: r.source_id,
        source_type: r.source_type,
        target_id: r.target_id,
        target_type: r.target_type,
        context: r.context,
        origin: r.origin,
        deleted_at: r.deleted_at,
        updated_at: r.updated_at,
        inserted_at: r.inserted_at,
        tag_id: r.tag_id,
        status: r.status
      })

    Repo.insert_all("relations", query)
  end

  def down do
    execute("DELETE FROM relations")
  end
end
