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

  def relation_definitions do
    %{
      AddRelation:
        swagger_schema do
          properties do
            relation(
              Schema.new do
                properties do
                  source_id(:string, "Id of the source of the relation to be created", required: true)
                  source_type(:string, "Type of the source of the relation to be created", required: true)
                  target_id(:string, "Id of the source of the relation to be created", required: true)
                  target_type(:string, "Type of the source of the relation to be created", required: true)
                  relation_type(:string, "Type of the persisted relation to be created", required: true)
                  context(:object, "Context informtation of the source and the target")
                end
              end
            )
          end
        end,
      Actions:
        swagger_schema do
          title("Actions")
          description("Relation actions")

          properties do
            action(
              Schema.new do
                properties do
                  method(:string)
                  input(:object)
                  link(:string)
                end
              end
            )
          end

          example(%{
            create: %{
              method: "POST",
              href: "/api/domains",
              input: %{}
            }
          })
        end,
      UpdateRelation:
        swagger_schema do
          properties do
            relation(
              Schema.new do
                properties do
                  source_id(:string, "Id of the source of the relation to be updated", required: true)
                  source_type(:string, "Type of the source of the relation to be updated", required: true)
                  target_id(:string, "Id of the source of the relation to be updated", required: true)
                  target_type(:string, "Type of the source of the relation to be updated", required: true)
                  relation_type(:string, "Type of the persisted relation to be updated", required: true)
                  context(:object, "Context informtation of the source and the updated")
                end
              end
            )
          end
      end,
      Relations:
        swagger_schema do
        title("Relations")
        description("A collection of relations")
        type(:array)
        items(Schema.ref(:Relation))
      end,
      RelationsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Relations))
            actions(Schema.ref(:Actions))
          end
        end,
      Relation:
        swagger_schema do
          title("Relation")
          description("Representation of a relation")

          properties do
            id(:integer, "Relation Id", required: true)
            source_id(:string, "Id of the source of the relation", required: true)
            source_type(:string, "Type of the source of the relation", required: true)
            target_id(:string, "Id of the source of the relation", required: true)
            target_type(:string, "Type of the source of the relation", required: true)
            relation_type(:string, "Type of the persisted relation", required: true)
            context(:object, "Context informtation of the source and the target", required: true)
          end
        end,
      RelationResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Relation))
          end
        end
    }
  end
end
