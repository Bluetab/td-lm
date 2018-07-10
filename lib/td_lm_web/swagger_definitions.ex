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
        end
    }
  end
end
