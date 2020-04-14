defmodule TdLm.Repo.Migrations.InsertDefaultTag do
  use Ecto.Migration

  alias TdLm.Repo
  alias TdLm.Resources
  alias TdLm.Resources.Tag

  @default_type "business_concept_to_field"

  def change do
    list_available_tags = Repo.all(Tag)

    exists_default_type =
      list_available_tags
      |> Enum.any?(fn t ->
        type_value =
          t
          |> Map.get(:value, %{})
          |> Map.get("type")

        type_value == @default_type
      end)

    if not exists_default_type do
      Resources.create_tag(%{value: %{"type" => @default_type}})
    end
  end
end
