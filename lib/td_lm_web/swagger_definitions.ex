defmodule TdLmWeb.SwaggerDefinitions do
  @moduledoc false
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
      ResourceFields:
        swagger_schema do
        title("Resource Fields")
        description("A collection of resource fields")
        type(:array)
        items(Schema.ref(:ResourceField))
      end,
      ResourceFieldsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:ResourceFields))
          end
        end,
      ResourceField:
        swagger_schema do
          title("Resource Field")
          description("Resource Field representation")

          properties do
            id(:integer, "Resource Field Id", required: true)
            resource_id(:string, "Resource", required: true)
            resource_type(:string, "Resource", required: true)
            field(:object, "Data field", required: true)
          end
        end,
      ResourceFieldResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:ResourceField))
          end
        end
    }
  end
end
