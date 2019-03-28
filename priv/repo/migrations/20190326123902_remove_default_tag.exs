defmodule TdLm.Repo.Migrations.RemoveDefaultTag do
  use Ecto.Migration

  alias TdLm.Repo
  alias TdLm.Resources
  alias TdLm.Resources.Relation
  alias TdLm.Resources.Tag

  import Ecto.Query, only: [from: 2]
  
  @default_type "business_concept_to_field"

  def change do
    Tag
    |> Repo.all
    |> Enum.filter(fn t -> 
      @default_type == t
      |> Map.get(:value, %{})
      |> Map.get("type")
    end)
    |> remove_relations_of_tags
    |> Enum.each(fn tag ->
      Resources.delete_tag(tag)
    end)

    Tag
    |> Repo.all
    |> Enum.filter(fn t -> 
      target_type = t
      |> Map.get(:value, %{})
      |> Map.get("target_type")
      is_nil(target_type)
    end)
    |> Enum.each(fn t -> 
      new_value = t
      |> Map.get(:value, %{})
      |> Map.put("target_type", "data_field")
      Resources.update_tag(t, %{value: new_value})
    end)
  end

  defp remove_relations_of_tags(tags) do
    tag_ids = Enum.map(tags, fn t -> t.id end)
    Repo.all(
      from r in Relation,
        preload: [:tags],
        join: tag in assoc(r, :tags),
        where: tag.id in ^tag_ids)
    |> Enum.each(fn r ->
      new_tags = r.tags
      |> Enum.filter(fn t -> not t.id in tag_ids end)
      Resources.update_relation(r, %{tags: new_tags})
    end)
    tags
  end
end
