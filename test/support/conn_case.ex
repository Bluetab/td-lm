defmodule TdLmWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common datastructures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  import TdLmWeb.Authentication, only: :functions

  alias Ecto.Adapters.SQL.Sandbox
  alias Phoenix.ConnTest

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import TdLm.Factory
      import TdLmWeb.Authentication, only: [create_acl_entry: 4]

      alias TdLmWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint TdLmWeb.Endpoint
    end
  end

  @admin_user_name "app-admin"

  setup tags do
    :ok = Sandbox.checkout(TdLm.Repo)
    start_supervised(MockPermissionResolver)

    unless tags[:async] do
      Sandbox.mode(TdLm.Repo, {:shared, self()})
      parent = self()

      case Process.whereis(TdLm.Cache.LinkLoader) do
        nil -> nil
        pid -> Sandbox.allow(TdLm.Repo, parent, pid)
      end
    end

    cond do
      tags[:admin_authenticated] ->
        @admin_user_name
        |> create_claims(role: "admin")
        |> create_user_auth_conn()

      user_name = tags[:authenticated_user] ->
        user_name
        |> create_claims()
        |> create_user_auth_conn()

      true ->
        {:ok, conn: ConnTest.build_conn()}
    end
  end
end
