defmodule TdLm.Application do
  @moduledoc false
  use Application
  alias TdLmWeb.Endpoint

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    env = Application.get_env(:td_lm, :env)

    # Define workers and child supervisors to be supervised
    children = [
      TdLm.Repo,
      TdLmWeb.Endpoint
    ] ++ children(env)

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

  defp children(:test), do: []

  defp children(_env) do
    [
      TdLm.Cache.LinkLoader,
      TdLm.Cache.LinkRemover,
      {TdCache.CacheCleaner, Application.get_env(:td_lm, :cache_cleaner, [])},
      TdLm.Scheduler
    ]
  end
end
