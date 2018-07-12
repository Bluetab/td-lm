defmodule TdLm.ResourceLinks.ResourceLink do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias TdLm.ResourceLinks.ResourceLink

  schema "resource_links" do
    field :resource_id, :string
    field :resource_type, :string
    field :field, :map

    timestamps()
  end

  @doc false
  def changeset(%ResourceLink{} = resource_link, attrs) do
    resource_link
    |> cast(attrs, [:resource_id, :resource_type, :field])
    |> validate_required([:resource_id, :resource_type, :field])
  end

end
