defmodule TdLmWeb.SwaggerDefinitions do
  @moduledoc false
  import PhoenixSwagger

  def link_definitions do
    %{
      Field:
        swagger_schema do
          title("Field")
          description("Link representation")
          type(:object)
        end,
        AddField:
        swagger_schema do
          properties do
            field(Schema.ref(:Field))
          end
        end,
      ResourceLinks:
        swagger_schema do
        title("Resource Links")
        description("A collection of resource links")
        type(:array)
        items(Schema.ref(:ResourceLink))
      end,
      ResourceLinksResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:ResourceLinks))
          end
        end,
      ResourceLink:
        swagger_schema do
          title("Resource Link")
          description("Resource Link representation")

          properties do
            id(:integer, "Resource Link Id", required: true)
            resource_id(:string, "Resource", required: true)
            resource_type(:string, "Resource", required: true)
            field(:object, "Data link", required: true)
          end
        end,
      ResourceLinkResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:ResourceLink))
          end
        end
    }
  end
end
