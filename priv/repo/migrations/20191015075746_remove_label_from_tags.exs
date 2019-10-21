defmodule TdLm.Repo.Migrations.RemoveLabelFromTags do
  use Ecto.Migration

  import Ecto.Query, only: [from: 2]

  alias TdLm.Repo
  alias TdLm.Resources
  alias TdLm.Resources.Tag
  alias TdLm.Resources.Relation

  def change do
    Tag
    |> Repo.all()
    |> Enum.each(fn tag ->
      query = from(r in Relation,
          join: tag in assoc(r, :tags),
          where: tag.id==^tag.id
        )
      query |> Repo.update_all(set: [updated_at: DateTime.utc_now()])

      new_value =
        tag
        |> Map.get(:value, %{})
        |> Map.drop(["label"])
      Resources.update_tag(tag, %{value: new_value})
    end)
  end
end
