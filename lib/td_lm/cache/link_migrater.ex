defmodule TdLm.Cache.LinkMigrater do
  @moduledoc """
  GenServer to copy field links to structure links.
  """

  @behaviour TdCache.EventStream.Consumer

  use GenServer

  alias TdLm.Cache.LinkLoader
  alias TdLm.Repo
  alias TdLm.Resources
  alias TdLm.Resources.Relation

  require Logger

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  ## EventStream.Consumer Callbacks

  @impl true
  def consume(events) do
    GenServer.call(__MODULE__, {:consume, events})
  end

  ## GenServer Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:consume, events}, _from, state) do
    reply =
      events
      |> Enum.map(&process/1)
      |> Enum.filter(&(&1 == :ok))
      |> Enum.count()

    {:reply, reply, state}
  end

  ## Private functions

  defp process(%{event: "unlink_field", field_id: field_id}) do
    Resources.list_relations_by_resource("data_field", field_id)
    |> Enum.map(&Resources.delete_relation/1)
    |> Enum.each(&post_unlink(&1, field_id))
  end

  defp process(%{event: "migrate_field", field_id: field_id, structure_id: structure_id}) do
    Resources.list_relations_by_resource("data_field", field_id)
    |> Enum.map(&with_tag_ids/1)
    |> Enum.map(&migration_changeset(&1, field_id, structure_id))
    |> Enum.map(&Repo.insert/1)
    |> Enum.each(&post_migrate(&1, field_id, structure_id))
  end

  defp process(_), do: :ok

  defp post_unlink({:ok, %{id: id}}, field_id) do
    LinkLoader.delete(id)
    Logger.info("Deleted relation #{id} for data_field:#{field_id}")
  end

  defp post_unlink({:error, changeset}, field_id) do
    Logger.warn("Failed deleting relation for data_field:#{field_id} - #{inspect(changeset)}")
  end

  defp post_migrate({:ok, %{id: id}}, field_id, structure_id) do
    LinkLoader.refresh(id)

    Logger.info(
      "Copied relation #{id} from data_field:#{field_id} to data_structure:#{structure_id}"
    )
  end

  defp post_migrate({:error, changeset}, field_id, structure_id) do
    Logger.warn(
      "Failed copying relation from data_field:#{field_id} to data_structure:#{structure_id} - #{
        inspect(changeset)
      }"
    )
  end

  defp migration_changeset(
         %{source_type: "data_field", source_id: field_id} = relation,
         field_id,
         structure_id
       ) do
    relation
    |> Map.take([:context, :target_type, :target_id, :tag_ids])
    |> Map.put(:source_type, "data_structure")
    |> Map.put(:source_id, structure_id)
    |> migration_changeset(field_id, structure_id)
  end

  defp migration_changeset(
         %{target_type: "data_field", target_id: field_id} = relation,
         field_id,
         structure_id
       ) do
    relation
    |> Map.take([:context, :source_type, :source_id, :tag_ids])
    |> Map.put(:target_type, "data_structure")
    |> Map.put(:target_id, structure_id)
    |> migration_changeset(field_id, structure_id)
  end

  defp migration_changeset(attrs, _, _) do
    %Relation{}
    |> Relation.create_changeset(attrs)
  end

  defp with_tag_ids(%Relation{tags: tags} = relation) do
    tag_ids = Enum.map(tags, & &1.id)

    relation
    |> Map.put(:tag_ids, tag_ids)
  end
end
