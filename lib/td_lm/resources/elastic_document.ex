defmodule TdLm.Relations.ElasticDocument do
  @moduledoc """
  Elasticsearch mapping and aggregation definition for relations
  """

  alias Elasticsearch.Document
  alias TdCache.I18nCache
  alias TdCore.Search.ElasticDocument
  alias TdCore.Search.ElasticDocumentProtocol
  alias TdLm.Resources.Relation

  defimpl Document, for: Relation do
    use ElasticDocument

    @keys [
      :id,
      :source_id,
      :source_type,
      :target_id,
      :target_type,
      :origin,
      :status,
      :updated_at,
      :deleted_at
    ]

    @impl Document
    def id(%Relation{id: id}), do: id

    @impl Document
    def routing(_), do: false

    @impl Document
    def encode(%Relation{} = relation) do
      {:ok, default_locale} = I18nCache.get_default_locale()
      active_locales = I18nCache.get_active_locales!() -- [default_locale]
      name_fields = fields_for_locales(active_locales)
      source_data = Map.get(relation, :source_data)
      target_data = Map.get(relation, :target_data)

      source_domains = Map.get(source_data, :domain_ids, [])
      source_name = Map.get(source_data, :name, "")
      target_domains = Map.get(target_data, :domain_ids, [])
      target_name = Map.get(target_data, :name, "")
      deleted = not is_nil(relation.deleted_at)

      relation
      |> Map.take(@keys)
      |> Map.put(:domain_ids, Enum.uniq(source_domains ++ target_domains))
      |> Map.put(:source_domain_ids, source_domains)
      |> Map.put(:source_name, source_name)
      |> Map.put(:ngram_source_name, source_name)
      |> Map.put(:target_domain_ids, target_domains)
      |> Map.put(:target_name, target_name)
      |> Map.put(:ngram_target_name, target_name)
      |> Map.put(:tag_type, get_tag_type(relation))
      |> Map.put(:source_data, source_data)
      |> Map.put(:target_data, target_data)
      |> Map.put(:deleted, deleted)
      |> add_locale_fields(source_data, :source, name_fields)
      |> add_locale_fields(target_data, :target, name_fields)
    end

    defp get_tag_type(%{tag: %{value: %{"type" => type}}}), do: type
    defp get_tag_type(_), do: nil

    defp add_locale_fields(payload, data, type, name_fields) do
      Enum.reduce(name_fields, payload, fn field, acc ->
        default = Map.get(payload, field[type][:default])
        Map.put(acc, field[type][:name], Map.get(data, field[:name], default))
      end)
    end

    defp fields_for_locales(active_locales) do
      Enum.reduce(active_locales, [], fn locale, acc ->
        acc ++
          [
            %{
              name: String.to_atom("name_#{locale}"),
              source: %{
                name: String.to_atom("source_name_#{locale}"),
                default: String.to_atom("source_name")
              },
              target: %{
                name: String.to_atom("target_name_#{locale}"),
                default: String.to_atom("target_name")
              }
            },
            %{
              name: String.to_atom("ngram_name_#{locale}"),
              source: %{
                name: String.to_atom("ngram_source_name_#{locale}"),
                default: String.to_atom("ngram_source_name")
              },
              target: %{
                name: String.to_atom("ngram_target_name_#{locale}"),
                default: String.to_atom("ngram_target_name")
              }
            }
          ]
      end)
    end
  end

  defimpl ElasticDocumentProtocol, for: Relation do
    use ElasticDocument

    @translatable_fields ~w(source_name target_name ngram_source_name ngram_target_name)a
    @search_fields ~w(source_name target_name)
    @search_as_you_type_fields ~w(ngram_source_name* ngram_target_name*)
    @exact_fields ~w(source_name target_name)

    def mappings(_) do
      properties = %{
        id: %{type: "long", index: false},
        domain_ids: %{type: "long"},
        tag_type: %{type: "text", fields: @raw_sort},
        source_id: %{type: "long", index: false},
        source_type: %{type: "keyword"},
        source_name: %{type: "text", fields: Map.merge(@raw_sort, @exact)},
        ngram_source_name: %{type: "search_as_you_type"},
        source_domain_ids: %{type: "long"},
        target_id: %{type: "long", index: false},
        target_type: %{type: "keyword"},
        target_name: %{type: "text", fields: Map.merge(@raw_sort, @exact)},
        ngram_target_name: %{type: "search_as_you_type"},
        target_domain_ids: %{type: "long"},
        origin: %{type: "keyword"},
        status: %{type: "keyword"},
        source_data: %{
          dynamic: false,
          properties: %{
            confidential: %{type: "boolean", fields: @raw},
            domain_ids: %{type: "long"},
            status: %{type: "keyword"}
          }
        },
        target_data: %{
          dynamic: false,
          properties: %{
            confidential: %{type: "boolean", fields: @raw},
            domain_ids: %{type: "long"},
            status: %{type: "keyword"}
          }
        },
        updated_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
        deleted_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"},
        deleted: %{type: "boolean"}
      }

      settings = Cluster.setting(:relations)

      %{
        mappings: %{properties: add_locales_fields_mapping(properties, @translatable_fields)},
        settings: settings
      }
    end

    def query_data(_) do
      %{
        query: %{
          simple: add_locales(@search_fields),
          as_you_type: @search_as_you_type_fields,
          exact: add_locales(@exact_fields)
        },
        aggs: aggregations(nil)
      }
    end

    def aggregations(_) do
      %{
        "status" => %{terms: %{field: "status", size: Cluster.get_size_field("status")}},
        "origin" => %{terms: %{field: "origin", size: Cluster.get_size_field("origin")}},
        "tag_type" => %{terms: %{field: "tag_type.raw", size: Cluster.get_size_field("tag_type")}},
        "taxonomy" => %{terms: %{field: "domain_ids", size: Cluster.get_size_field("taxonomy")}},
        "source_taxonomy" => %{
          terms: %{field: "source_domain_ids", size: Cluster.get_size_field("source_taxonomy")},
          meta: %{type: "domain"}
        },
        "target_taxonomy" => %{
          terms: %{field: "target_domain_ids", size: Cluster.get_size_field("target_taxonomy")},
          meta: %{type: "domain"}
        },
        "deleted" => %{
          terms: %{field: "deleted", size: Cluster.get_size_field("deleted")}
        }
      }
    end
  end
end
