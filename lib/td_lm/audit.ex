defmodule TdLm.Audit do
  @moduledoc """
  The Link Manager Audit context. The public functions in this module are
  designed to be called using `Ecto.Multi.run/5`, although the first argument
  (`repo`) is not currently used.
  """

  alias TdCache.ConceptCache
  alias TdCache.IngestCache
  alias TdDfLib.Templates

  @doc """
  Publishes a `:relation_deleted` event. Should be called using `Ecto.Multi.run/5`.
  """
  def relation_deleted(_repo, %{relation: relation}, user_id) do
    do_relation_deleted(relation, user_id)
  end

  @doc """
  Publishes a `:relation_created` event. Should be called using `Ecto.Multi.run/5`.
  """
  def relation_created(_repo, %{relation: relation}, %{changes: changes}, user_id) do
    do_relation_created(relation, changes, user_id)
  end

  @doc """
  Publishes `:relations_deprecated` events. Should be called using `Ecto.Multi.run/5`.
  """
  def relations_deprecated(_repo, %{deprecated: {_, [_ | _] = relations}}) do
    relations
    |> Enum.map(&do_relation_deprecated/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> case do
      %{error: errors} -> {:error, errors}
      %{ok: event_ids} -> {:ok, event_ids}
    end
  end

  def relations_deprecated(_repo, _), do: {:ok, []}

  @doc """
  Publishes a `:tag_deleted` event. Should be called using `Ecto.Multi.run/5`.
  """
  def tag_deleted(_repo, %{tag: tag}, user_id) do
    do_tag_deleted(tag, user_id)
  end

  @doc """
  Publishes a `:tag_created` event. Should be called using `Ecto.Multi.run/5`.
  """
  def tag_created(_repo, %{tag: tag}, user_id) do
    do_tag_created(tag, user_id)
  end

  @doc """
  Publishes a `:tag_updated` event. Should be called using `Ecto.Multi.run/5`.
  """
  def tag_updated(_repo, %{tag: tag}, user_id) do
    do_tag_updated(tag, user_id)
  end

  defp do_relation_deleted(%{source_type: source_type, source_id: source_id} = relation, user_id) do
    payload = payload(relation)
    publish("relation_deleted", source_type, source_id, user_id, payload)
  end

  defp do_relation_deprecated(%{source_type: source_type, source_id: source_id} = relation) do
    payload = payload(relation)
    publish("relation_deprecated", source_type, source_id, 0, payload)
  end

  defp payload(relation) do
    relation
    |> Map.take([:id, :target_id, :target_type, :context, :subscribable_fields])
    |> put_subscribable_fields(relation)
    |> put_domain_ids(relation)
  end

  defp put_subscribable_fields(payload, %{source_type: "business_concept", source_id: source_id}) do
    case ConceptCache.get(source_id) do
      {:ok, concept = %{}} ->
        Map.put(payload, :subscribable_fields, subscribable_fields(concept))

      _ ->
        payload
    end
  end

  defp put_subscribable_fields(payload, _relation), do: payload

  defp subscribable_fields(%{content: content}) when map_size(content) == 0, do: %{}

  defp subscribable_fields(%{type: type, content: content}) do
    Map.take(content, Templates.subscribable_fields(type))
  end

  defp do_relation_created(
         %{id: id, source_type: source_type, source_id: source_id} = relation,
         changes,
         user_id
       ) do
    changes =
      case tags_from_changes(changes) do
        [] ->
          Map.delete(changes, :tags)

        tags ->
          changes
          |> Map.delete(:tags)
          |> Map.put(:relation_types, tags)
          |> Map.put(:id, id)
      end

    changes = changes |> put_subscribable_fields(relation) |> put_domain_ids(relation)
    publish("relation_created", source_type, source_id, user_id, changes)
  end

  defp do_tag_created(%{id: id, value: _value} = tag, user_id) do
    payload = Map.take(tag, [:value])
    publish("tag_created", "tag", id, user_id, payload)
  end

  defp do_tag_updated(%{id: id, value: _value} = tag, user_id) do
    payload = Map.take(tag, [:value])
    publish("tag_updated", "tag", id, user_id, payload)
  end

  defp do_tag_deleted(%{id: id}, user_id) do
    publish("tag_deleted", "tag", id, user_id)
  end

  defp tags_from_changes(%{tags: tags}) do
    tags
    |> Enum.filter(&(&1.action == :update))
    |> Enum.flat_map(fn
      %{data: %{value: %{"type" => type}}} -> [type]
      _ -> []
    end)
    |> Enum.sort()
    |> Enum.uniq()
  end

  defp tags_from_changes(_), do: []

  defp put_domain_ids(payload, %{source_type: "business_concept", source_id: source_id}) do
    case ConceptCache.get(source_id, :domain_ids) do
      {:ok, [_ | _] = domain_ids} -> Map.put(payload, :domain_ids, domain_ids)
      _ -> payload
    end
  end

  defp put_domain_ids(payload, %{source_type: "ingest", source_id: source_id})
       when not is_integer(source_id) do
    Map.put(payload, :domain_ids, IngestCache.get_domain_ids(source_id))
  end

  defp put_domain_ids(payload, _), do: payload

  defp publish(event, resource_type, resource_id, user_id, payload \\ %{}) do
    TdCache.Audit.publish(
      event: event,
      resource_type: resource_type,
      resource_id: resource_id,
      user_id: user_id,
      payload: payload
    )
  end
end
