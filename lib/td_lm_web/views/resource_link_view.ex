defmodule TdLmWeb.ResourceLinkView do
  use TdLmWeb, :view
  use TdHypermedia, :view

  alias TdLmWeb.ResourceLinkView

  def render("resource_links.json", %{resource_links: resource_links, hypermedia: hypermedia}) do
    render_many_hypermedia(resource_links, hypermedia, ResourceLinkView, "resource_link.json")
  end

  def render("resource_links.json", %{resource_links: resource_links}) do
    %{data: render_many(resource_links, ResourceLinkView, "resource_link.json")}
  end

  def render("resource_link.json", %{resource_link: resource_link}) do
    %{
      id: resource_link.id,
      resource_id: resource_link.resource_id,
      resource_type: resource_link.resource_type,
      field: resource_link.field
    }
  end
end
