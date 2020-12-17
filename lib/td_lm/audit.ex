defmodule TdLm.Audit do
  @moduledoc """
  The Link Manager Audit context. The public functions in this module are
  designed to be called using `Ecto.Multi.run/5`, although the first argument
  (`repo`) is not currently used.
  """

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

  defp do_relation_deleted(%{source_type: source_type, source_id: source_id} = relation, user_id) do
    payload = Map.take(relation, [:id, :target_id, :target_type, :context])
    publish("relation_deleted", source_type, source_id, user_id, payload)
  end

  defp do_relation_deprecated(%{source_type: source_type, source_id: source_id} = relation) do
    payload = Map.take(relation, [:id, :target_id, :target_type, :context])
    publish("relation_deprecated", source_type, source_id, nil, payload)
  end

  defp do_relation_created(
         %{id: id, source_type: source_type, source_id: source_id},
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

    publish("relation_created", source_type, source_id, user_id, changes)
  end

  defp do_tag_created(%{id: id, value: _value} = tag, user_id) do
    payload = Map.take(tag, [:value])
    publish("tag_created", "tag", id, user_id, payload)
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
