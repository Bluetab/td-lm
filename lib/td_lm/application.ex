defmodule TdLm.Application do
  @moduledoc false
  use Application
  alias TdLmWeb.Endpoint

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    relation_remover_worker = %{
      id: TdLm.RelationRemover,
      start: {TdLm.RelationRemover, :start_link, []}
    }

    # Define workers and child supervisors to be supervised
    children =
      [
        # Start the Ecto repository
        supervisor(TdLm.Repo, []),
        # Start the endpoint when the application starts
        supervisor(TdLmWeb.Endpoint, []),
        # Start your own worker by calling: TdLm.Worker.start_link(arg1, arg2, arg3)
        # worker(TdLm.Worker, [arg1, arg2, arg3]),
        # worker(TdLm.CacheCleaner, [TdLm.CacheCleaner]),
        %{
          id: TdLm.CustomSupervisor,
          start:
            {TdLm.CustomSupervisor, :start_link,
             [%{children: [relation_remover_worker], strategy: :one_for_one}]},
          type: :supervisor
        }
      ] ++ relation_loader_workers() ++ cache_cleaner_workers()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TdLm.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end

  defp relation_loader_workers do
    import Supervisor.Spec
    config = Application.get_env(:td_lm, :relation_loader)
    [worker(TdLm.RelationLoader, [config])]
  end

  defp cache_cleaner_workers do
    import Supervisor.Spec
    config = Application.get_env(:td_lm, :cache_cleaner, [])
    [worker(TdCache.CacheCleaner, [config])]
  end
end
