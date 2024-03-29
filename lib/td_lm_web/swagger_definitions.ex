defmodule TdLmWeb.SwaggerDefinitions do
  @moduledoc false
  import PhoenixSwagger

  def relation_definitions do
    %{
      AddRelation:
        swagger_schema do
          properties do
            relation(
              Schema.new do
                properties do
                  source_id(:integer, "Id of the source of the relation to be created",
                    required: true
                  )

                  source_type(:string, "Type of the source of the relation to be created",
                    required: true
                  )

                  target_id(:integer, "Id of the target of the relation to be created",
                    required: true
                  )

                  target_type(:string, "Type of the target of the relation to be created",
                    required: true
                  )

                  context(:object, "Context information of the source and the target")
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
            context(:object, "Context information of the source and the target", required: true)
            source_id(:integer, "Id of the source of the relation", required: true)
            source_type(:string, "Type of the source of the relation", required: true)
            target_id(:integer, "Id of the source of the relation", required: true)
            target_type(:string, "Type of the source of the relation", required: true)
            inserted_at(:string, "insert timestamp")
            updated_at(:string, "update timestamp")
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
            source_id(:integer, "Id of the source of the relation", required: false)
            source_type(:string, "Type of the source of the relation", required: false)
            target_id(:integer, "Id of the source of the relation", required: false)
            target_type(:string, "Type of the source of the relation", required: false)
            context(:object, "Context information of the source and the target", required: false)
            value(:object, "Value of the relation type", required: false)
          end

          example(%{
            id: "1",
            source_id: 1,
            source_type: "business_concept",
            target_id: 2,
            target_type: "data_filed",
            context: %{},
            value: %{type: "business_concept_to_field"}
          })
        end
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
                  target_type(:string, "Target type", required: false)
                end
              end
            )
          end
        end,
      TagSearch:
        swagger_schema do
          properties do
            value(
              Schema.new do
                properties do
                  type(:string, "Tag type code", required: false)
                  target_type(:string, "Target type", required: false)
                end
              end
            )
          end

          example(%{
            value: %{
              target_type: "ingest"
            }
          })
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
