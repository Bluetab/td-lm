defmodule TdLm.Repo.Migrations.RemoveLabelFromTags do
  use Ecto.Migration

  import Ecto.Query

  alias TdLm.Repo

  def up do
    "tags"
    |> where([t], not is_nil(t.value["label"]))
    |> select([t], {t.id, t.value})
    |> Repo.all()
    |> Enum.map(fn {id, value} -> {id, Map.delete(value, "label")} end)
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
