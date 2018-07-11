defmodule TdLm.ResourceFields do
  @moduledoc """
  The ResourceFields context.
  """

  import Ecto.Query, warn: false
  alias TdLm.Repo
  alias TdLm.ResourceFields.ResourceField

  def list_resource_fields(resource_id, resource_type) do
    Repo.all(from(r in ResourceField,
      where: r.resource_id == ^resource_id
      and r.resource_type == ^resource_type))
  end

  def get_resource_field(id) do
    Repo.one(from(r in ResourceField,
      where: r.id == ^id))
  end

  def get_resource_field!(id) do
    Repo.one!(from(r in ResourceField,
      where: r.id == ^id))
  end

  def create_resource_field(attrs \\ %{}) do
    %ResourceField{}
    |> ResourceField.changeset(attrs)
    |> Repo.insert()
  end

  def delete_resource_field(%ResourceField{} = resource_field) do
    Repo.delete(resource_field)
  end

end
