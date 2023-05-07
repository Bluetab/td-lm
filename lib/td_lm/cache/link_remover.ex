defmodule TdLm.Cache.LinkRemover do
  @moduledoc """
  GenServer to copy field links to structure links.
  """

  @behaviour TdCache.EventStream.Consumer

  use GenServer

  require Logger

  alias TdLm.Auth.Claims
  alias TdLm.Resources

  @system_claims %Claims{user_id: 0, user_name: "system"}

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
  def init(opts) do
    {:ok, %{parent: Keyword.get(opts, :parent)}}
  end

  @impl true
  def handle_call({:consume, events}, _from, %{parent: parent} = state) do
    reply =
      events
      |> Enum.map(&process/1)
      |> Enum.filter(&(&1 == :ok))
      |> Enum.count()

    # Notify parent that events have been consumed (for tests)
    if parent != nil, do: send(parent, {:consumed, events})

    {:reply, reply, state}
  end

  ## Private functions

  defp process(%{event: "delete_link", link_id: id} = e) do
    Logger.info("#{inspect(e)}")

    case Resources.get_relation(String.to_integer(id)) do
      nil -> :ok
      resource -> Resources.delete_relation(resource, @system_claims)
    end
  end

  defp process(e), do: Logger.info("#{inspect(e)}")
end
