defmodule TdLm.Repo.Migrations.LoadTypesIntoTags do
  use Ecto.Migration

  import Ecto.Query
  alias TdLm.Repo
  alias TdLm.Resources.Tag

  def change do
    tags_with_relation_types = fetch_tags_with_relation_types()
    Repo.insert_all(Tag, tags_with_relation_types)
  end

  defp fetch_tags_with_relation_types do
    inserted_at = DateTime.utc_now()
    updated_at = DateTime.utc_now()

    from(
      r in "relations", 
      select: %{
          relation_type: r.relation_type
        }
    )
    |> distinct(true)
    |> Repo.all()
    |> Enum.map(fn %{relation_type: relation_type} -> 
      value = Map.new() |> Map.put("type", relation_type)
      Map.new()
       |> Map.put(:value, value)
       |> Map.put(:inserted_at, inserted_at)
       |> Map.put(:updated_at, updated_at)
    end)
  end
end
