defmodule TdLmWeb.SwaggerDefinitions do
  import PhoenixSwagger

  def field_definitions do
    %{
      Field:
        swagger_schema do
          title("Field")
          description("Field representation")
          type(:object)
        end,
      AddField:
        swagger_schema do
          properties do
            field(Schema.ref(:Field))
          end
        end,
      ConceptField:
        swagger_schema do
          title("Concept Field")
          description("Concept Field representation")

          properties do
            id(:integer, "Concept Field Id", required: true)
            concept(:string, "Business Concept", required: true)
            field(:object, "Data field", required: true)
          end
        end,
      ConceptFieldResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:ConceptField))
          end
        end
    }
  end
end
