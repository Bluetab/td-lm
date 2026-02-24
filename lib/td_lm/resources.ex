defmodule TdLm.Resources do
  @moduledoc """
  The Resources context.
  """

  import Canada, only: [can?: 2]
  import Ecto.Query

  require Logger

  alias Ecto.Multi

  alias TdCache.ConceptCache
  alias TdCache.DomainCache
  alias TdCache.LinkCache
  alias TdCache.StructureCache
  alias TdCluster.Cluster.TdBg
  alias TdCluster.Cluster.TdDd
  alias TdCore.Search.Store
  alias TdLm.Audit
  alias TdLm.Auth.Claims
  alias TdLm.Cache.LinkLoader
  alias TdLm.Graph.Data
  alias TdLm.Repo
  alias TdLm.Resources.Relation
  alias TdLm.Resources.Tag
  alias TdLm.Search.Indexer

  @relations_keys [
    "source_param",
    "source_type",
    "concept_type",
    "target_param",
    "target_type",
    "domain_external_id"
  ]

  @index_to_resource_type %{
    concepts: "business_concept",
    quality_controls: "quality_control",
    structures: "data_structure"
  }

  @system_user_id 0

  def list_relations(params \\ %{}) do
    params
    |> Enum.reduce(Relation, fn
      {"id", id}, q -> where(q, [r], r.id == ^id)
      {"limit", limit}, q -> limit(q, ^limit)
      {"min_id", min_id}, q -> where(q, [r], r.id >= ^min_id)
      {"since", since}, q -> where(q, [r], r.updated_at >= ^since)
      {"source_id", id}, q -> where(q, [r], r.source_id == ^id)
      {"source_type", t}, q -> where(q, [r], r.source_type == ^t)
      {"target_id", id}, q -> where(q, [r], r.target_id == ^id)
      {"target_type", t}, q -> where(q, [r], r.target_type == ^t)
      {"status", "approved" = status}, q -> where(q, [r], r.status == ^status or is_nil(r.status))
      {"status", status}, q -> where(q, [r], r.status == ^status)
      {"tag_id", t}, q -> where(q, [r], r.tag_id == ^t)
      {"value", %{} = value}, q -> where_relation_value(q, value)
    end)
    |> order_by([:updated_at, :id])
    |> preload(:tag)
    |> Repo.all()
  end

  defp where_relation_value(q, %{} = value) do
    q = join(q, :left, [r], _ in assoc(r, :tag))

    Enum.reduce(value, q, fn {k, v}, q ->
      where(q, [_, rt], rt.value[^k] in ^List.wrap(v))
    end)
  end

  @doc """
  Gets a single relation.   Raises `Ecto.NoResultsError` if the Relation does not exist.
  """
  def get_relation!(id) do
    Relation
    |> Repo.get!(id)
    |> Repo.preload(:tag)
  end

  def get_relation(id), do: Repo.get(Relation, id)

  @doc """
  Creates a relation and publishes an audit event.
  """
  def clone_relations(original_source_id, new_source_id, relation_type, %{
        __struct__: _,
        user_id: user_id
      }) do
    %{"target_type" => relation_type, "source_id" => original_source_id}
    |> list_relations()
    |> Enum.map(fn %{
                     source_type: source_type,
                     target_id: target_id,
                     target_type: target_type,
                     status: status,
                     tag_id: tag_id
                   } ->
      %{
        "source_id" => new_source_id,
        "source_type" => source_type,
        "target_id" => target_id,
        "target_type" => target_type,
        "status" => status,
        "tag_id" => tag_id
      }
    end)
    |> Enum.map(&create_relation(&1, %Claims{user_id: user_id}))
  end

  def create_relation(%{} = params, %Claims{user_id: user_id}) do
    changeset = Relation.changeset(params)

    Multi.new()
    |> Multi.insert(:relation, changeset)
    |> Multi.run(:relation_with_optional_tag, fn _, changes -> maybe_preload_tag(changes) end)
    |> Multi.run(:audit, Audit, :relation_created, [changeset, user_id])
    |> Repo.transaction()
    |> tap(&on_create/1)
    |> then(fn
      {:ok, %{relation_with_optional_tag: relation_with_optional_tag} = response} ->
        {:ok, %{response | relation: relation_with_optional_tag}}

      error ->
        error
    end)
  end

  def upsert_relations(relations, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, @system_user_id)
    cleanup_params = Keyword.get(opts, :cleanup_params, [])
    now = DateTime.utc_now()

    placeholders = %{
      inserted_at: {:placeholder, :now},
      updated_at: {:placeholder, :now}
    }

    relations = Enum.map(relations, &Map.merge(&1, placeholders))

    Multi.new()
    |> Multi.insert_all(:relations, Relation, relations,
      placeholders: %{now: now},
      on_conflict: {:replace, [:updated_at, :origin]},
      conflict_target:
        {:unsafe_fragment,
         "(source_id, source_type, target_id, target_type, COALESCE(tag_id, -1)) WHERE deleted_at IS NULL"},
      returning: true
    )
    |> maybe_cleanup_relations(cleanup_params, user_id)
    |> Multi.run(:audit_creation, Audit, :bulk_relation_creation, [user_id])
    |> Repo.transaction()
    |> tap(fn
      {:ok, %{relations: {_count, relations}, stale_relations: {_count_stale, stale_relations}}} ->
        upserted_ids = Enum.map(relations, & &1.id)
        LinkLoader.refresh(upserted_ids)
        Indexer.reindex(upserted_ids)

        stale_ids = Enum.map(stale_relations, & &1.id)
        Enum.each(stale_ids, &LinkCache.delete(&1, publish: false))
        Indexer.delete(stale_ids)

      {:ok, %{relations: {_count, relations}}} ->
        upserted_ids = Enum.map(relations, & &1.id)
        LinkLoader.refresh(upserted_ids)
        Indexer.reindex(upserted_ids)

      _other ->
        :noop
    end)
  end

  defp maybe_cleanup_relations(multi, [_ | _] = cleanup_params, user_id) do
    multi
    |> Multi.delete_all(:stale_relations, fn %{relations: {_count, relations}} ->
      cleanup_params
      |> Enum.reduce(Relation, fn
        {:origin, origin}, q -> where(q, [r], r.origin == ^origin)
        {:source_id, source_id}, q -> where(q, [r], r.source_id == ^source_id)
        {:source_type, source_type}, q -> where(q, [r], r.source_type == ^source_type)
        {:target_id, target_id}, q -> where(q, [r], r.target_id == ^target_id)
        {:target_type, target_type}, q -> where(q, [r], r.target_type == ^target_type)
      end)
      |> where([r], r.id not in ^Enum.map(relations, & &1.id))
      |> where([r], is_nil(r.deleted_at))
      |> select([r], r)
    end)
    |> Multi.run(:audit_deletion, Audit, :relation_deleted, [user_id])
  end

  defp maybe_cleanup_relations(multi, [], _user_id), do: multi

  defp maybe_preload_tag(%{relation: %{tag_id: nil} = relation}),
    do: {:ok, Map.put(relation, :tag, nil)}

  defp maybe_preload_tag(%{relation: relation}) do
    relation_with_tag = Repo.preload(relation, :tag)

    legacy_relation =
      relation_with_tag
      |> Map.get(:tag)
      |> List.wrap()
      |> then(&%Relation{relation_with_tag | tags: &1})

    {:ok, legacy_relation}
  end

  defp on_create({:ok, %{relations: {_, inserted}} = res}) when is_list(inserted) do
    ids = Enum.map(inserted, & &1.id)
    LinkLoader.refresh(ids)
    {:ok, res}
  end

  defp on_create({:ok, %{relation: %{id: id, status: nil}}} = res) do
    LinkLoader.refresh(id)
    Indexer.reindex([id])
    res
  end

  defp on_create({:ok, %{relation: %{id: id}}} = res) do
    Indexer.reindex([id])
    res
  end

  defp on_create(res), do: res

  def update_relations_status(
        %{"relation_ids" => [_ | _] = relation_ids, "status" => status},
        claims
      ) do
    %Claims{user_id: user_id} = claims
    ts = DateTime.utc_now()

    Multi.new()
    |> Multi.all(:relations, fn _changes ->
      from(r in Relation, where: r.id in ^relation_ids)
      |> preload(:tag)
    end)
    |> Multi.run(:cache_data, fn _repo, %{relations: relations} ->
      {:ok, get_cache_data(relations)}
    end)
    |> Multi.run(:allowed_relations, fn _repo, %{relations: relations} ->
      permission_check(relations, claims)
    end)
    |> Multi.run(:relations_validation, fn _repo, %{allowed_relations: %{allowed: relations}} ->
      changeset_check(relations, status)
    end)
    |> Multi.update_all(:relations_updated, &update_valid_relations/1,
      set: [updated_at: ts, status: status]
    )
    |> Multi.run(:audit, Audit, :relations_status_updated, [user_id])
    |> Multi.run(:relations_preload, fn repo, %{relations_updated: {count, relations}} ->
      relation_ids = Enum.map(relations, & &1.id)

      preloaded_relations =
        Relation
        |> where([r], r.id in ^relation_ids)
        |> preload(:tag)
        |> repo.all()

      {:ok, {count, preloaded_relations}}
    end)
    |> Repo.transaction()
    |> on_update(status)
  end

  defp permission_check(relations, claims) do
    relations
    |> Enum.reduce(
      %{allowed: [], errors: []},
      fn relation, acc ->
        if can?(claims, update(relation)) do
          %{acc | allowed: acc.allowed ++ [relation]}
        else
          error = {relation, [permissions: {"forbidden", []}]}
          %{acc | errors: acc.errors ++ [error]}
        end
      end
    )
    |> then(&{:ok, &1})
  end

  defp changeset_check(relations, status) do
    relations
    |> Enum.reduce(
      %{valid: [], errors: []},
      fn relation, acc ->
        case Relation.status_changeset(relation, %{status: status}) do
          %{valid?: true} ->
            %{acc | valid: acc.valid ++ [relation]}

          %{errors: changeset_errors} ->
            error = {relation, changeset_errors}
            %{acc | errors: acc.errors ++ [error]}
        end
      end
    )
    |> then(&{:ok, &1})
  end

  defp update_valid_relations(%{relations_validation: %{valid: relations}}) do
    relation_ids =
      Enum.map(relations, fn %{id: relation_id} -> relation_id end)

    Relation
    |> where([r], r.id in ^relation_ids)
    |> select([r], r)
  end

  defp on_update(
         {:ok,
          %{
            allowed_relations: %{errors: allowed_errors},
            relations_validation: %{errors: validation_errors},
            relations_preload: {_, relations_updated},
            audit: audit_events,
            cache_data: cache_data
          }},
         status
       ) do
    updated_relation_ids = Enum.map(relations_updated, & &1.id)

    if status == "approved" do
      LinkLoader.refresh(updated_relation_ids)
    end

    Indexer.reindex(updated_relation_ids)

    errors =
      Enum.map(allowed_errors ++ validation_errors, fn {relation, errors} ->
        {relations_map(relation, cache_data), errors}
      end)

    {:ok,
     %{
       relations_updated: relations_map(relations_updated, cache_data),
       errors: errors,
       audit: audit_events
     }}
  end

  defp on_bulk_create({:ok, %{:relation_ids => [_ | _] = relation_ids}} = res) do
    LinkLoader.refresh(relation_ids)
    res
  end

  defp on_bulk_create(res), do: res

  def bulk_create_relations({:ok, parsed_data}, claims),
    do: bulk_create_relations(parsed_data, claims)

  def bulk_create_relations({:error, :invalid_headers}, _claims) do
    {:ok,
     %{
       "created" => [],
       "errors" => [
         %{
           "error_type" => "invalid_headers",
           "body" => %{
             "message" => "bulk_creation_link.upload.failed.invalid_headers"
           }
         }
       ],
       "updated" => []
     }}
  end

  def bulk_create_relations({:error, _} = error, _claims), do: error

  def bulk_create_relations([], _claims),
    do:
      {:ok,
       %{
         "created" => [],
         "errors" => [],
         "updated" => []
       }}

  def bulk_create_relations(bulk_insert_params, claims) do
    %{"bulk_insert_params" => bulk_insert_params, "errors" => []}
    |> check_params()
    |> check_duplicates()
    |> check_availability()
    |> check_permissions(claims)
    |> check_already_exists()
    |> bulk_relation_creation(claims)
    |> resume_process()
    |> then(&{:ok, &1})
  end

  defp update_error(params, error) do
    Enum.map(params, &Map.put(&1, "error", error))
  end

  defp update_data(new_errors, valids, %{"errors" => errors} = data)
       when length(new_errors) > 0 do
    data
    |> Map.put("bulk_insert_params", valids)
    |> Map.put("errors", errors ++ new_errors)
  end

  defp update_data([], valids, data), do: Map.put(data, "bulk_insert_params", valids)

  defp check_params(%{"bulk_insert_params" => bulk_insert_params} = data) do
    {errors, valids} =
      Enum.reduce(bulk_insert_params, {[], []}, fn candidate, {error, valids} ->
        missing_params =
          Enum.filter(@relations_keys, fn key ->
            not Map.has_key?(candidate, key) or
              is_nil(Map.get(candidate, key)) or
              (is_binary(Map.get(candidate, key)) and String.trim(Map.get(candidate, key)) == "")
          end)

        if Enum.empty?(missing_params) do
          {error, [candidate | valids]}
        else
          candidate_with_missing = Map.put(candidate, "missing_params", missing_params)
          {[candidate_with_missing | error], valids}
        end
      end)

    errors
    |> Enum.reverse()
    |> update_error("missing_params")
    |> update_data(Enum.reverse(valids), data)
  end

  defp check_availability(%{"bulk_insert_params" => bulk_insert_params} = data) do
    tags =
      %{}
      |> list_tags()
      |> Enum.into(%{}, fn %{id: id, value: %{"target_type" => target_type, "type" => type}} ->
        {{target_type, type}, id}
      end)

    {:ok, domain_external_id_map} =
      DomainCache.external_id_to_id_map()

    {valids, errors} =
      Enum.map(
        bulk_insert_params,
        fn
          %{
            "row_number" => row_number,
            "source_param" => source_param,
            "source_type" => source_type,
            "target_param" => target_param,
            "target_type" => target_type,
            "concept_type" => concept_type,
            "domain_external_id" => domain_external_id
          } = params ->
            tag_target_type = Map.get(params, "tag_target_type", nil)

            tag_type = Map.get(params, "link_type", nil)

            domain_id = Map.get(domain_external_id_map, domain_external_id, nil)

            tag_id = Map.get(tags, {tag_target_type, tag_type}, nil)

            {source_status, source_id, source_type, source_data} =
              check_data(source_param, source_type, domain_id, concept_type)

            {target_status, target_id, target_type, target_data} =
              check_data(target_param, target_type, domain_id, nil)

            %{
              "row_number" => row_number,
              "relation_id" => nil,
              "source_id" => source_id,
              "source_type" => source_type,
              "source_status" => source_status,
              "source_param" => source_param,
              "target_id" => target_id,
              "target_type" => target_type,
              "target_param" => target_param,
              "target_status" => target_status,
              "tag_id" => tag_id,
              "domain_external_id" => domain_external_id,
              "source_data" => source_data,
              "target_data" => target_data
            }
        end
      )
      |> Enum.split_with(fn
        %{"source_status" => :available, "target_status" => :available} -> true
        _ -> false
      end)

    errors
    |> update_error("not_available")
    |> update_data(valids, data)
  end

  defp check_data(_search_param, "business_concept" = type, nil, _concept_type) do
    {:not_exists, nil, type, nil}
  end

  defp check_data(search_param, "business_concept" = type, domain_id, concept_type) do
    search_param
    |> TdBg.get_unique_concept(domain_id, concept_type)
    |> extract_and_check(
      :versions,
      type
    )
  end

  defp check_data(search_param, "data_structure" = type, _domain, _concept_type) do
    search_param
    |> TdDd.get_data_structure_by_external_id(:latest_version)
    |> extract_and_check(:latest_version, type)
  end

  defp check_data(search_param, "implementation" = type, _domain, _concept_type) do
    search_param
    |> TdDd.get_implementations_by_ref()
    |> extract_and_check(:status, type)
  end

  defp extract_and_check({:ok, nil}, _key, type), do: {:not_exists, nil, type, nil}

  defp extract_and_check({:ok, data}, _key, type) when is_map(data) and map_size(data) == 0,
    do: {:not_exists, nil, type, nil}

  defp extract_and_check({:ok, %{id: id} = data}, key, type) do
    status =
      data
      |> Map.take([key])
      |> do_check()

    {status, id, type, data}
  end

  defp extract_and_check(error, _key, type) do
    Logger.error("Error in extract_and_check for type: #{type} and error: #{inspect(error)}")
    {:error, nil, type, nil}
  end

  defp do_check(%{versions: [%{status: "deprecated"} | _]}),
    do: :deprecated

  defp do_check(%{latest_version: %{deleted_at: deleted_at}}) when not is_nil(deleted_at),
    do: :deleted

  defp do_check(_), do: :available

  defp check_duplicates(%{"bulk_insert_params" => []} = data), do: data

  defp check_duplicates(%{"bulk_insert_params" => bulk_insert_params} = data) do
    {valids, duplicates, _seen_keys} =
      Enum.reduce(bulk_insert_params, {[], [], MapSet.new()}, fn map,
                                                                 {valids_acc, duplicates_acc,
                                                                  seen_keys} ->
        link_type = Map.get(map, "link_type", nil)
        normalized_link_type = if link_type == "" or is_nil(link_type), do: nil, else: link_type

        key = {
          Map.get(map, "source_param"),
          Map.get(map, "source_type"),
          Map.get(map, "concept_type"),
          Map.get(map, "target_param"),
          Map.get(map, "target_type"),
          Map.get(map, "domain_external_id"),
          normalized_link_type
        }

        if MapSet.member?(seen_keys, key) do
          {valids_acc, [map | duplicates_acc], seen_keys}
        else
          {[map | valids_acc], duplicates_acc, MapSet.put(seen_keys, key)}
        end
      end)

    reversed_duplicates = Enum.reverse(duplicates)
    reversed_valids = Enum.reverse(valids)

    reversed_duplicates
    |> update_error("duplicate_in_file")
    |> update_data(reversed_valids, data)
  end

  defp check_permissions(%{"bulk_insert_params" => bulk_insert_params} = data, claims) do
    {valids, errors} =
      bulk_insert_params
      |> Enum.reduce({[], []}, fn params, {valids_acc, errors_acc} ->
        process_permission_check(params, claims, valids_acc, errors_acc)
      end)
      |> then(fn {valids, errors} -> {Enum.reverse(valids), Enum.reverse(errors)} end)

    errors
    |> update_error("without_permissions")
    |> update_data(valids, data)
  end

  defp process_permission_check(params, claims, valids_acc, errors_acc) do
    case params do
      %{"source_type" => "business_concept"} ->
        check_business_concept_permissions(params, claims, valids_acc, errors_acc)

      _ ->
        check_standard_permissions(params, claims, valids_acc, errors_acc)
    end
  end

  defp check_business_concept_permissions(params, claims, valids_acc, errors_acc) do
    %{
      "source_id" => source_id,
      "source_type" => source_type,
      "source_data" => source_data,
      "target_id" => target_id,
      "target_type" => target_type,
      "target_data" => target_data
    } = params

    source_can =
      can?(
        claims,
        create(%{
          resource_id: source_id,
          resource_type: source_type,
          business_concept: source_data
        })
      )

    target_can =
      can?(
        claims,
        create(%{
          target_id: target_id,
          target_type: target_type,
          structure: target_data
        })
      )

    handle_permission_result(params, source_can, target_can, valids_acc, errors_acc)
  end

  defp check_standard_permissions(params, claims, valids_acc, errors_acc) do
    %{
      "source_id" => source_id,
      "source_type" => source_type,
      "target_type" => target_type,
      "target_data" => target_data
    } = params

    source_can = can?(claims, create(%{resource_id: source_id, resource_type: source_type}))

    target_can =
      can?(
        claims,
        create(%{
          target_type: target_type,
          structure: target_data
        })
      )

    handle_permission_result(params, source_can, target_can, valids_acc, errors_acc)
  end

  defp handle_permission_result(params, source_can, target_can, valids_acc, errors_acc) do
    if source_can && target_can do
      {[params | valids_acc], errors_acc}
    else
      updated_params =
        params
        |> maybe_update_source_status(source_can)
        |> maybe_update_target_status(target_can)

      {valids_acc, [updated_params | errors_acc]}
    end
  end

  defp maybe_update_source_status(param, true), do: param

  defp maybe_update_source_status(param, false) do
    Map.put(param, "source_status", :no_permission)
  end

  defp maybe_update_target_status(param, true), do: param

  defp maybe_update_target_status(param, false) do
    Map.put(param, "target_status", :no_permission)
  end

  defp check_already_exists(%{"bulk_insert_params" => []} = data), do: data

  defp check_already_exists(%{"bulk_insert_params" => bulk_insert_params} = data) do
    search_query =
      bulk_insert_params
      |> Enum.map(fn %{
                       "source_id" => source_id,
                       "source_type" => source_type,
                       "target_id" => target_id,
                       "target_type" => target_type,
                       "tag_id" => tag_id
                     } ->
        base =
          dynamic(
            [r],
            r.source_id == ^source_id and
              r.source_type == ^source_type and
              r.target_id == ^target_id and
              r.target_type == ^target_type
          )

        if is_nil(tag_id) do
          dynamic([r], ^base and is_nil(r.tag_id))
        else
          dynamic([r], ^base and r.tag_id == ^tag_id)
        end
      end)
      |> Enum.reduce(fn dyn, acc -> dynamic([r], ^acc or ^dyn) end)

    existing_relations =
      Relation
      |> where(^search_query)
      |> select([r], {r.source_id, r.source_type, r.target_id, r.target_type, r.tag_id})
      |> Repo.all()
      |> MapSet.new()

    {errors, valids} =
      Enum.split_with(bulk_insert_params, fn %{
                                               "source_id" => source_id,
                                               "source_type" => source_type,
                                               "target_id" => target_id,
                                               "target_type" => target_type,
                                               "tag_id" => tag_id
                                             } ->
        MapSet.member?(
          existing_relations,
          {source_id, source_type, target_id, target_type, tag_id}
        )
      end)

    errors
    |> update_error("already_exists")
    |> update_data(valids, data)
  end

  defp bulk_relation_creation(
         %{"bulk_insert_params" => []} = data,
         _claims
       ),
       do: {{:ok, %{relations: {0, []}}}, data}

  defp bulk_relation_creation(
         %{"bulk_insert_params" => bulk_insert_params} = data,
         %{user_id: user_id}
       ) do
    result =
      bulk_insert_params
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {relation_param, index}, multi ->
        changeset = Relation.changeset(%Relation{}, relation_param)

        multi_name = {:insert_relation, index}
        Multi.insert(multi, multi_name, changeset)
      end)
      |> Multi.run(:audit, Audit, :bulk_relation_creation, [user_id])
      |> Multi.run(:relation_ids, fn _, changes ->
        Enum.map(changes, fn
          {{:insert_relation, _}, inserted} ->
            inserted.id

          _ ->
            nil
        end)
        |> Enum.reject(&is_nil/1)
        |> then(&{:ok, &1})
      end)
      |> Repo.transaction()
      |> on_bulk_create()

    {result, data}
  end

  defp resume_process({
         {:ok, data} = _multi_result,
         %{"errors" => errors}
       }) do
    %{}
    |> Map.put("created", Map.get(data, :relation_ids, []))
    |> Map.put("updated", [])
    |> Map.put("errors", format_error_response(errors))
  end

  defp format_error_response(errors) do
    errors
    |> Enum.sort_by(& &1["row_number"])
    |> Enum.map(fn
      %{
        "error" => error_type,
        "row_number" => row_number
      } = error_content ->
        {error, message} = parse_error_and_messages(error_content, error_type)

        %{
          "error_type" => error_type,
          "body" => %{
            "message" => message,
            "context" => %{
              "row" => row_number,
              "error" => error
            }
          }
        }
    end)
  end

  defp parse_error_and_messages(
         %{
           "error" => "not_available",
           "source_type" => source_type,
           "target_type" => target_type,
           "source_status" => source_status,
           "target_status" => target_status
         },
         error_type
       ) do
    cond do
      source_status != :available and target_status != :available ->
        {"#{source_type} && #{target_type}",
         "bulk_creation_link.upload.failed.#{error_type}.source.#{source_status}.target.#{target_status}"}

      source_status != :available ->
        {"#{source_type}", "bulk_creation_link.upload.failed.#{error_type}.#{source_status}"}

      target_status != :available ->
        {"#{target_type}", "bulk_creation_link.upload.failed.#{error_type}.#{target_status}"}
    end
  end

  defp parse_error_and_messages(%{"error" => "already_exists"}, error_type),
    do: {"", "bulk_creation_link.upload.failed.#{error_type}"}

  defp parse_error_and_messages(%{"error" => "duplicate_in_file"}, error_type),
    do: {"", "bulk_creation_link.upload.failed.#{error_type}"}

  defp parse_error_and_messages(
         %{
           "error" => "missing_params",
           "missing_params" => missing_params
         },
         error_type
       ) do
    {Enum.join(missing_params, ", "), "bulk_creation_link.upload.failed.#{error_type}"}
  end

  defp parse_error_and_messages(
         %{
           "error" => "without_permissions",
           "domain_external_id" => domain_external_id,
           "source_status" => :no_permission
         },
         error_type
       ) do
    {domain_external_id, "bulk_creation_link.upload.failed.#{error_type}"}
  end

  defp parse_error_and_messages(
         %{
           "error" => "without_permissions",
           "target_status" => :no_permission,
           "target_type" => target_type
         },
         error_type
       ) do
    {"#{target_type}", "bulk_creation_link.upload.failed.#{error_type}"}
  end

  @doc """
  Deletes a relation and publishes an audit event.
  """
  def delete_relation(%Relation{} = relation, %Claims{user_id: user_id}) do
    Multi.new()
    |> Multi.delete(:relation, relation)
    |> Multi.run(:audit, Audit, :relation_deleted, [user_id])
    |> Repo.transaction()
    |> on_delete_relation()
  end

  defp on_delete_relation({:ok, %{relation: %{id: id}}} = res) do
    LinkLoader.delete(id)
    Indexer.delete([id])
    res
  end

  def delete_stale_relations(resource_type, resource_ids) do
    Multi.new()
    |> Multi.delete_all(
      :stale_relations,
      Relation
      |> where([r], r.source_type == ^resource_type and r.source_id in ^resource_ids)
      |> or_where([r], r.target_type == ^resource_type and r.target_id in ^resource_ids)
      |> select([r], r)
    )
    |> Multi.run(:audit, Audit, :relation_deleted, [@system_user_id])
    |> Repo.transaction()
    |> tap(fn
      {:ok, %{stale_relations: {_count, relations}}} ->
        ids = Enum.map(relations, & &1.id)
        Enum.each(ids, &LinkCache.delete(&1, publish: false))
        Indexer.delete(ids)

      _other ->
        :noop
    end)
  end

  def refresh_search_data(index, resource_ids) do
    @index_to_resource_type
    |> Map.get(index)
    |> list_relation_ids(resource_ids)
    |> Indexer.reindex()
  end

  def count_relations(params \\ []) do
    params
    |> Enum.reduce(Relation, fn
      {:source_type, source_type}, query ->
        where(query, [r], r.source_type == ^source_type)

      {:source_id, source_id}, query ->
        where(query, [r], r.source_id == ^source_id)

      {:target_type, target_type}, query ->
        where(query, [r], r.target_type == ^target_type)

      {:target_id, target_id}, query ->
        where(query, [r], r.target_id == ^target_id)
    end)
    |> where([r], is_nil(r.deleted_at))
    |> Repo.aggregate(:count, :id)
  end

  defp list_relation_ids(resource_type, :all) when is_binary(resource_type) do
    Relation
    |> where([r], is_nil(r.deleted_at))
    |> where([r], r.source_type == ^resource_type)
    |> or_where([r], r.target_type == ^resource_type)
    |> select([r], r.id)
    |> Repo.all()
  end

  defp list_relation_ids(resource_type, resource_ids) when is_binary(resource_type) do
    resource_ids = List.wrap(resource_ids)

    Relation
    |> where([r], is_nil(r.deleted_at))
    |> where([r], r.source_type == ^resource_type and r.source_id in ^resource_ids)
    |> or_where([r], r.target_type == ^resource_type and r.target_id in ^resource_ids)
    |> select([r], r.id)
    |> Repo.all()
  end

  defp list_relation_ids(_resource_type, _resource_id), do: []

  @doc """
  Returns the list of tags.
  """
  def list_tags(params \\ %{}) do
    params
    |> Enum.reduce(Tag, fn
      {"value", %{} = value}, q -> where_tag_value(q, value)
    end)
    |> Repo.all()
  end

  defp where_tag_value(q, %{} = value) do
    Enum.reduce(value, q, fn {k, v}, q ->
      where(q, [t], t.value[^k] in ^List.wrap(v))
    end)
  end

  @doc """
  Gets a single tag.

  Raises `Ecto.NoResultsError` if the Tag does not exist.
  """
  def get_tag!(id) do
    Repo.get!(Tag, id)
  end

  @doc """
  Gets a single tag.

  Returns nil if the Tag does not exist.
  """
  def get_tag(id), do: Repo.get(Tag, id)

  @doc """
  Gets a single tag by type

  Returns nil if the Tag does not exist.
  """
  def get_tag_by_type(nil, _target_type), do: %{}
  def get_tag_by_type("", _target_type), do: %{}

  def get_tag_by_type(type, target_type) do
    Tag
    |> where([t], fragment("?->>'type' = ?", t.value, ^type))
    |> where([t], fragment("?->>'target_type' = ?", t.value, ^target_type))
    |> Repo.one()
  end

  @doc """
  Creates a tag and publishes and audit event.
  """
  def create_tag(%{} = params, %Claims{user_id: user_id}) do
    changeset = Tag.changeset(%Tag{}, params)

    if changeset.valid? do
      Multi.new()
      |> Multi.insert(:tag, changeset)
      |> Multi.run(:audit, Audit, :tag_created, [user_id])
      |> Repo.transaction()
      |> maybe_refresh_tag_cache()
    else
      {:error, :tag, changeset, %{}}
    end
  end

  @doc """
  Updates a tag and publishes and audit event.
  """
  def update_tag(tag, params, %Claims{user_id: user_id}) do
    changeset = Tag.changeset(tag, params)

    Multi.new()
    |> Multi.update(:tag, changeset)
    |> Multi.run(:audit, Audit, :tag_updated, [user_id])
    |> Repo.transaction()
    |> maybe_refresh_tag_cache()
  end

  defp maybe_refresh_tag_cache({:ok, _} = res) do
    LinkLoader.refresh_tags()
    res
  end

  defp maybe_refresh_tag_cache(error), do: error

  @doc """
  Deletes a tag and publishes an audit event.
  """
  def delete_tag(%Tag{id: id} = tag, %Claims{user_id: user_id}) do
    Multi.new()
    |> Multi.update_all(:relations, Relation |> where([r], r.tag_id == ^id) |> select([r], r.id),
      set: [updated_at: DateTime.utc_now()]
    )
    |> Multi.delete(:tag, tag)
    |> Multi.run(:audit, Audit, :tag_deleted, [user_id])
    |> Repo.transaction()
    |> on_delete_tag()
  end

  defp on_delete_tag(res) do
    with {:ok, %{relations: {count, ids}, tag: %{id: tag_id}}} = res when count > 0 <- res do
      LinkLoader.refresh(ids)
      LinkLoader.delete_tag(tag_id)
      res
    end
  end

  def list_stale_relations(resource_type, active_ids) do
    Relation
    |> where([r], r.source_type == ^resource_type and r.source_id not in ^active_ids)
    |> or_where([r], r.target_type == ^resource_type and r.target_id not in ^active_ids)
    |> Repo.all()
  end

  @spec deprecate(String.t(), list(integer)) ::
          :ok | {:ok, map} | {:error, Multi.name(), any, %{required(Multi.name()) => any}}
  def deprecate(resource_type, [_ | _] = resource_ids) do
    ts = DateTime.utc_now()

    query =
      Relation
      |> where([r], r.source_type == ^resource_type and r.source_id in ^resource_ids)
      |> or_where([r], r.target_type == ^resource_type and r.target_id in ^resource_ids)
      |> where([r], is_nil(r.deleted_at))
      |> select([r], r)

    Multi.new()
    |> Multi.update_all(:deprecated, query, set: [deleted_at: ts])
    |> Multi.run(:audit, Audit, :relations_deprecated, [])
    |> Repo.transaction()
    |> tap(&on_deprecate/1)
  end

  def deprecate(_resource_type, []), do: {:ok, %{deprecated: {0, []}}}

  defp on_deprecate({:ok, %{deprecated: {_count, relations}}}) do
    ids = Enum.map(relations, & &1.id)
    Indexer.reindex(ids)
  end

  defp on_deprecate(_res), do: :noop

  def migrate_impl_id_to_impl_ref([]), do: []

  def migrate_impl_id_to_impl_ref(relations) do
    relations
    |> Enum.chunk_every(2)
    |> Enum.map(fn relation ->
      {_, relations} = update_implementation_relation(relation)
      relations
    end)
    |> List.flatten()
    |> Enum.filter(&(&1 != nil))
    |> Enum.map(fn %{id: id} -> id end)
  end

  defp update_implementation_relation([implementation_id, implementation_ref]) do
    Relation
    |> where([r], r.source_type == "implementation" and r.source_id == ^implementation_id)
    |> select([r], r)
    |> Repo.update_all(set: [source_type: "implementation_ref", source_id: implementation_ref])
  end

  @spec activate(String.t(), list(integer)) :: :ok | {:ok, map}
  def activate(resource_type, [_ | _] = resource_ids) do
    reply =
      Relation
      |> where([r], r.source_type == ^resource_type and r.source_id in ^resource_ids)
      |> or_where([r], r.target_type == ^resource_type and r.target_id in ^resource_ids)
      |> where([r], not is_nil(r.deleted_at))
      |> select([r], r)
      |> Repo.update_all(set: [deleted_at: nil])

    {:ok, %{activated: reply}}
  end

  def activate(_resource_type, []), do: {:ok, %{activated: {0, []}}}

  def find_tags(clauses) do
    clauses
    |> Enum.reduce(Tag, fn
      {:id, {:in, ids}}, q -> where(q, [t], t.id in ^ids)
    end)
    |> Repo.all()
  end

  def graph(claims, id, resource_type, opts \\ []) do
    id = Data.id(resource_type, id)

    g = Data.graph()

    case Graph.has_vertex?(g, id) do
      true ->
        all =
          g
          |> Data.all([id])
          |> Enum.map(&Graph.vertex(g, &1))
          |> Enum.reject(&reject_by_type(&1, opts[:types]))
          # credo:disable-for-next-line
          |> Enum.reject(&reject_by_permissions(&1, claims))
          |> Enum.uniq_by(&Map.get(&1, :id))

        ids = Enum.map(all, &Map.get(&1, :id))
        subgraph = Graph.subgraph(g, ids)
        %{nodes: nodes(all), edges: edges(subgraph)}

      _ ->
        %{nodes: [], edges: []}
    end
  end

  defp reject_by_type(%{label: %{resource_type: type}}, [_ | _] = types) do
    type not in types
  end

  defp reject_by_type(_vertex, _types), do: false

  defp reject_by_permissions(%{label: label}, claims) do
    not can?(claims, show(Map.take(label, [:resource_id, :resource_type])))
  end

  defp nodes(nodes) do
    nodes
    |> Enum.map(&Map.take(&1, [:id, :label]))
    |> Enum.map(fn %{id: id, label: label} ->
      Map.new()
      |> Map.put(:id, id)
      |> Map.merge(Map.take(label, [:resource_id, :resource_type]))
    end)
  end

  defp edges(graph) do
    graph
    |> Graph.get_edges()
    |> Enum.map(fn %{id: id, label: label, v1: v1, v2: v2} ->
      tag = Map.get(label, :tag)

      Map.new()
      |> Map.put(:id, id)
      |> Map.put(:source_id, v1)
      |> Map.put(:target_id, v2)
      |> Map.put(:tag, tag)
    end)
  end

  def get_cache_data(relations) do
    relations
    |> Enum.reduce(
      %{business_concept: [], data_structure: []},
      fn relation, acc ->
        %{
          source_type: source_type,
          source_id: source_id,
          target_type: target_type,
          target_id: target_id
        } = relation

        acc
        |> Map.update(String.to_atom(source_type), [source_id], fn ids -> [source_id | ids] end)
        |> Map.update(String.to_atom(target_type), [target_id], fn ids -> [target_id | ids] end)
      end
    )
    |> then(fn %{business_concept: bc_ids, data_structure: ds_ids} ->
      %{
        business_concepts: get_concepts_from_cache(bc_ids),
        data_structures: get_structures_from_cache(ds_ids)
      }
    end)
  end

  defp get_concepts_from_cache(ids) when is_list(ids) do
    ids
    |> ConceptCache.get_many()
    |> case do
      {:ok, []} ->
        %{}

      {:ok, concepts_cached} ->
        Map.new(concepts_cached, fn concept -> {concept.id, concept} end)
    end
  end

  defp get_structures_from_cache(ids) do
    ids
    |> StructureCache.get_many()
    |> case do
      {:ok, []} ->
        %{}

      {:ok, structures_cached} ->
        Map.new(structures_cached, fn structure -> {structure.id, structure} end)
    end
  end

  defp relations_map(relations, cache_data) when is_list(relations),
    do: Enum.map(relations, &relations_map(&1, cache_data))

  defp relations_map(relation, cache_data) do
    relation
    |> Map.put(:source_data, get_data(relation.source_type, relation.source_id, cache_data))
    |> Map.put(:target_data, get_data(relation.target_type, relation.target_id, cache_data))
  end

  def get_data("business_concept", id, %{business_concepts: business_concepts}) do
    case Map.get(business_concepts, id) do
      nil ->
        %{}

      %{domain_id: domain_id, shared_to_ids: shared_to_ids} = concept ->
        Map.put(concept, :domain_ids, [domain_id | shared_to_ids])
    end
  end

  def get_data("data_structure", id, %{data_structures: data_structures}) do
    Map.get(data_structures, id, %{})
  end

  def search_data(relations) do
    relations
    |> Enum.reduce(%{}, fn %{
                             source_type: source_type,
                             source_id: source_id,
                             target_type: target_type,
                             target_id: target_id
                           },
                           acc ->
      acc
      |> Map.update(source_type, [source_id], fn ids -> [source_id | ids] end)
      |> Map.update(target_type, [target_id], fn ids -> [target_id | ids] end)
    end)
    |> Map.take(["business_concept", "data_structure", "quality_control"])
    |> Task.async_stream(fn
      {"business_concept", ids} ->
        concept_map =
          :concepts
          |> Store.fetch(ids)
          |> Map.new(fn concept -> {concept.business_concept_id, concept} end)

        {"business_concept", concept_map}

      {"data_structure", ids} ->
        structure_map =
          :structures
          |> Store.fetch(ids)
          |> Map.new(fn structure -> {structure.data_structure_id, structure} end)

        {"data_structure", structure_map}

      {"quality_control", ids} ->
        quality_control_map =
          :quality_controls
          |> Store.fetch(ids)
          |> Map.new(fn quality_control ->
            {quality_control.quality_control_id, quality_control}
          end)

        {"quality_control", quality_control_map}
    end)
    |> Map.new(fn {:ok, pairs} -> pairs end)
  end
end
