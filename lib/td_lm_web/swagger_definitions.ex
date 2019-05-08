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
            context(:object, "Context informtation of the source and the target", required: true)
          end
        end,
      RelationResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Relation))
          end
        end,
        RelationFilterRequest:
          swagger_schema do
            properties do
              id(:integer, "Relation Id", required: true)
              source_id(:string, "Id of the source of the relation", required: false)
              source_type(:string, "Type of the source of the relation", required: false)
              target_id(:string, "Id of the source of the relation", required: false)
              target_type(:string, "Type of the source of the relation", required: false)
              context(:object, "Context informtation of the source and the target", required: false)
              value(:object, "Value of the relation type", required: false)
            end

          example(%{
            id: "1",
            source_id: "1",
            source_type: "business_concept",
            target_id: "2",
            target_type: "data_filed",
            context: %{},
            value: %{type: "business_concept_to_field"}})
        end,
    }
  end

  def tag_definitions do
    %{
      CreateTag:
        swagger_schema do
          properties do
            tag(Schema.ref(:TagEdit))
          end
        end,
      UpdateTag:
        swagger_schema do
          properties do
            tag(Schema.ref(:TagEdit))
          end
      end,
      Tags:
        swagger_schema do
        title("Tags")
        description("A collection of tags")
        type(:array)
        items(Schema.ref(:Tag))
      end,
      TagsResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Tags))
          end
        end,
      Tag:
        swagger_schema do
          title("Tag")
          description("Representation of a tag")

          properties do
            id(:integer, "Tag Id", required: true)
            value(
              Schema.new do
                properties do
                  type(:string, "Tag type code", required: true)
                  label(:string, "Tag label", required: false)
                  target_type(:string, "Target type", required: false)
                end
              end
            )
          end
        end,
      TagEdit:
        swagger_schema do
          title("Tag")
          description("Representation of a tag")

          properties do
            value(
              Schema.new do
                properties do
                  type(:string, "Tag type code", required: true)
                  label(:string, "Tag label", required: false)
                  target_type(:string, "Target type", required: false)
                end
              end
            )
          end
        end,
      TagResponse:
        swagger_schema do
          properties do
            data(Schema.ref(:Tag))
          end
        end
    }
  end
end
