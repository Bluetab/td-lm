defmodule TdLmWeb.ResourceFieldView do
  use TdLmWeb, :view
  # TODO: Define hyper media
  # use TdLm.Hypermedia, :view

  alias TdLmWeb.ResourceFieldView

  def render("resource_fields.json", %{resource_fields: resource_fields}) do
    %{data: render_many(resource_fields, ResourceFieldView, "resource_field.json")}
  end

  def render("resource_field.json", %{resource_field: resource_field}) do
    %{
      id: resource_field.id,
      resource_id: resource_field.resource_id,
      resource_type: resource_field.resource_type,
      field: resource_field.field
    }
  end
end
