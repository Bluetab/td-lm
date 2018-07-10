defmodule TdLm.ConceptFields.ConceptField do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias TdLm.ConceptFields.ConceptField

  schema "concept_fields" do
    field :concept, :string
    field :field, :map

    timestamps()
  end

  @doc false
  def changeset(%ConceptField{} = concept_field, attrs) do
    concept_field
    |> cast(attrs, [:concept, :field])
    |> validate_required([:concept, :field])
  end

end