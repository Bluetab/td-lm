defmodule TdLm.Repo.Migrations.RemoveDefaultTag do
  use Ecto.Migration

  import Ecto.Query

  alias TdLm.Repo

  @default_type "business_concept_to_field"

  def up do
    "tags"
    |> where([t], t.value["type"] == ^@default_type)
    |> Repo.delete_all()

    "tags"
    |> where([t], is_nil(t.value["target_type"]))
    |> select([t], {t.id, t.value})
    |> Repo.all()
    |> Enum.map(fn {id, value} -> {id, Map.put(value, "target_type", "data_field")} end)
    |> Enum.map(fn {id, new_value} ->
      "tags"
      |> where([t], t.id == ^id)
      |> Repo.update_all(set: [value: new_value])
    end)
  end

  def down do
    :ok
  end
end
