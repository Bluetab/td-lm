defmodule TdDq.ConceptFieldsTest do
  use TdLm.DataCase
  alias TdLm.ConceptFields
  alias TdLm.ConceptFields.ConceptField

  describe "concept_fields" do

    defp fixture_valid_concept_field do
      %{concept: "BC ID 1", field: %{"ou" => "World Dev Indicators", "Field" => "Series name"}}
    end

    test "create_concept_field/1 with valid data creates a concept_field" do
      valid_concept_field = fixture_valid_concept_field()
      {:ok, %ConceptField{} = result} =
        valid_concept_field
          |> ConceptFields.create_concept_field
      assert result.concept == valid_concept_field.concept &&
      result.field == valid_concept_field.field
    end

    test "create_concept_field/1 having not field in data returns an error" do
      assert {:error, %Ecto.Changeset{}} =
        fixture_valid_concept_field()
        |> Map.delete(:field)
        |> ConceptFields.create_concept_field
    end

  end
end
