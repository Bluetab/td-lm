defmodule TdLm.Resources.Tag do
  use Ecto.Schema
  import Ecto.Changeset


  schema "tags" do
    field :value, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:value])
    |> validate_required([:value])
  end
end
