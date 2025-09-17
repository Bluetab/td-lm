defmodule TdLm.Resources do
  @moduledoc """
  The Resources context.
  """

  import Canada, only: [can?: 2]
  import Ecto.Query

  require Logger

  alias Ecto.Multi
  alias TdCache.DomainCache
  alias TdCluster.Cluster.TdBg
  alias TdCluster.Cluster.TdDd
  alias TdLm.Audit
  alias TdLm.Auth.Claims
  alias TdLm.Cache.LinkLoader
  alias TdLm.Graph.Data
  alias TdLm.Repo
  alias TdLm.Resources.Relation
  alias TdLm.Resources.Tag

  @relations_keys [
    "source_param",
    "source_type",
    "target_param",
    "target_type",
    "domain_external_id"
  ]

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

  @spec count_relations_by_source(any, any) :: map
  def count_relations_by_source(source_type, target_type) do
    Relation
    |> Repo.all()
    |> Enum.group_by(& &1.source_id)
    |> Enum.map(fn {key, value} ->
      {key, count_valid_relations(value, source_type, target_type)}
    end)
    |> Map.new()
  end

  defp count_valid_relations(value, source_type, target_type) do
    Enum.count(value, fn r ->
      r.source_type == source_type and r.target_type == target_type
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
                     tag_id: tag_id
                   } ->
      %{
        "source_id" => new_source_id,
        "source_type" => source_type,
        "target_id" => target_id,
        "target_type" => target_type,
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

  defp on_create(res) do
    with {:ok, %{relation: %{id: id}}} <- res do
      LinkLoader.refresh(id)
      res
    end
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
    |> update_error("missing_params")
    |> update_data(valids, data)
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
            "domain_external_id" => domain_external_id
          } = params ->
            tag_target_type = Map.get(params, "tag_target_type", nil)

            tag_type = Map.get(params, "link_type", nil)

            domain_id = Map.get(domain_external_id_map, domain_external_id, nil)

            tag_id = Map.get(tags, {tag_target_type, tag_type}, nil)

            {source_status, source_id, source_type, source_data} =
              check_data(source_param, source_type, domain_id)

            {target_status, target_id, target_type, target_data} =
              check_data(target_param, target_type, domain_id)

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

  defp check_data(_search_param, "business_concept" = type, nil) do
    {:not_exists, nil, type, nil}
  end

  defp check_data(search_param, "business_concept" = type, domain_id) do
    search_param
    |> TdBg.get_concept_by_name_in_domain(domain_id)
    |> extract_and_check(
      :versions,
      type
    )
  end

  defp check_data(search_param, "data_structure" = type, _domain) do
    search_param
    |> TdDd.get_data_structure_by_external_id(:latest_version)
    |> extract_and_check(:latest_version, type)
  end

  defp check_data(search_param, "implementation" = type, _domain) do
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
    groups =
      Enum.group_by(bulk_insert_params, fn map ->
        {
          map["source_param"],
          map["source_type"],
          map["target_param"],
          map["target_type"],
          map["domain_external_id"],
          map["link_type"]
        }
      end)

    {valids, duplicates} =
      Enum.reduce(groups, {[], []}, fn {_key, items}, {u_acc, d_acc} ->
        items
        |> Enum.reverse()
        |> then(fn
          [first | rest] -> {[first | u_acc], rest ++ d_acc}
          [] -> {u_acc, d_acc}
        end)
      end)

    duplicates
    |> update_error("duplicate_in_file")
    |> update_data(valids, data)
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
          base
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

  defp on_delete_relation(res) do
    with {:ok, %{relation: %{id: id}}} <- res do
      LinkLoader.delete(id)
      res
    end
  end

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
  end

  def deprecate(_resource_type, []), do: {:ok, %{deprecated: {0, []}}}

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
end
