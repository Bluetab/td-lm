defmodule TdLmWeb.LinkController do
  require Logger
  import Canada, only: [can?: 2]
  use TdLmWeb, :controller
  use PhoenixSwagger
  alias TdLm.Audit
  alias TdLm.ConceptFields
  alias TdLmWeb.ConceptFieldView

  @events %{
    add_concept_field: "add_concept_field",
    delete_concept_field: "delete_concept_field"
  }

  swagger_path :add_field do
    post("/business_concept/{business_concept_id}/fields")
    description("Updates Business Concept Version Field")
    produces("application/json")

    parameters do
      field(:body, Schema.ref(:AddField), "Concept field")
      business_concept_id(:path, :integer, "Business Concept ID", required: true)
    end

    response(200, "OK", Schema.ref(:ConceptFieldResponse))
    response(400, "Client Error")
  end

  def add_field(conn, %{"business_concept_id" => id, "domain_id" => domain_id, "field" => field}) do
    user = conn.assigns[:current_user]
    create_attrs = %{concept: id, field: field}

    with true <- can?(user, add_field(id)),
     {:ok, concept_field} <- ConceptFields.create_concept_field(create_attrs) do

      audit = %{
        "audit" => %{
          "resource_id" => id,
          "resource_type" => "concept",
          "payload" => create_attrs
        }
      }

      Audit.create_event(conn, audit, @events.add_concept_field)

      render(conn, ConceptFieldView, "concept_field.json", concept_field: concept_field)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> render(ErrorView, :"403.json")

      error ->
        Logger.error("While adding  concept fields... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end
end
