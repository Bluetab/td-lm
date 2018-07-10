defmodule TdLmWeb.ConceptFieldView do
  use TdLmWeb, :view
  # TODO: Define hyper media
  # use TdLm.Hypermedia, :view

  alias TdLmWeb.ConceptFieldView

  def render("concept_fields.json", %{concept_fields: concept_fields}) do
    %{data: render_many(concept_fields, ConceptFieldView, "concept_field.json")}
  end

  def render("concept_field.json", %{concept_field: concept_field}) do
    %{
      id: concept_field.id,
      concept: concept_field.concept,
      field: concept_field.field
    }
  end
end
