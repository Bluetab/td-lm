defmodule TdLm.ResourceLinks do
  @moduledoc """
  The ResourceLinks context.
  """

  import Ecto.Query, warn: false
  alias TdLm.Repo
  alias TdLm.ResourceLinks.ResourceLink

  def list_resource_links(resource_id, resource_type) do
    Repo.all(from(r in ResourceLink,
      where: r.resource_id == ^resource_id
      and r.resource_type == ^resource_type))
  end

  def get_resource_link(id) do
    Repo.one(from(r in ResourceLink,
      where: r.id == ^id))
  end

  def get_resource_link!(id) do
    Repo.one!(from(r in ResourceLink,
      where: r.id == ^id))
  end

  def create_resource_link(attrs \\ %{}) do
    %ResourceLink{}
    |> ResourceLink.changeset(attrs)
    |> Repo.insert()
  end

  def delete_resource_link(%ResourceLink{} = resource_link) do
    Repo.delete(resource_link)
  end

  def list_links do
    Repo.all(ResourceLink)
  end

end
