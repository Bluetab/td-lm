defmodule TdLm.Relations.ElasticDocument do
  @moduledoc """
  Elasticsearch mapping and aggregation definition for relations
  """

  alias Elasticsearch.Document
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
      :updated_at
    ]

    @impl Document
    def id(%Relation{id: id}), do: id

    @impl Document
    def routing(_), do: false

    @impl Document
    def encode(%Relation{} = relation) do
      source_data =
        Map.get(relation, :source_data)

      target_data =
        Map.get(relation, :target_data)

      source_domains = Map.get(source_data, :domain_ids, [])
      source_name = Map.get(source_data, :name, "")
      target_domains = Map.get(target_data, :domain_ids, [])
      target_name = Map.get(target_data, :name, "")

      relation
      |> Map.take(@keys)
      |> Map.put(:domain_ids, Enum.uniq(source_domains ++ target_domains))
      |> Map.put(:source_domain_ids, source_domains)
      |> Map.put(:source_name, source_name)
      |> Map.put(:target_domain_ids, target_domains)
      |> Map.put(:target_name, target_name)
      |> Map.put(:tag_type, get_tag_type(relation))
    end

    defp get_tag_type(%{tag: %{value: %{"type" => type}}}), do: type
    defp get_tag_type(_), do: nil
  end

  defimpl ElasticDocumentProtocol, for: Relation do
    use ElasticDocument

    @search_fields ~w(source_name target_name)

    def mappings(_) do
      properties = %{
        id: %{type: "long", index: false},
        domain_ids: %{type: "long"},
        tag_type: %{type: "text", fields: @raw_sort},
        source_id: %{type: "long", index: false},
        source_type: %{type: "keyword"},
        source_name: %{type: "text", fields: @raw_sort},
        source_domain_ids: %{type: "long"},
        target_id: %{type: "long", index: false},
        target_type: %{type: "keyword"},
        target_name: %{type: "text", fields: @raw_sort},
        target_domain_ids: %{type: "long"},
        origin: %{type: "keyword"},
        status: %{type: "keyword"},
        updated_at: %{type: "date", format: "strict_date_optional_time||epoch_millis"}
      }

      settings = Cluster.setting(:relations)

      %{mappings: %{properties: properties}, settings: settings}
    end

    def query_data(_) do
      %{
        fields: @search_fields,
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
        }
      }
    end
  end
end
