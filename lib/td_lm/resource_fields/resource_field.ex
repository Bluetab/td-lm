defmodule TdLm.ResourceFields.ResourceField do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias TdLm.ResourceFields.ResourceField

  schema "resource_fields" do
    field :resource_id, :string
    field :resource_type, :string
    field :field, :map

    timestamps()
  end

  @doc false
  def changeset(%ResourceField{} = resource_field, attrs) do
    resource_field
    |> cast(attrs, [:resource_id, :resource_type, :field])
    |> validate_required([:resource_id, :resource_type, :field])
  end

end
