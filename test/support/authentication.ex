defmodule TdLmWeb.Authentication do
  @moduledoc """
  This module defines the functions required to add auth headers to requests in
  the tests
  """
  import Plug.Conn

  alias Phoenix.ConnTest
  alias TdLm.Auth.Claims
  alias TdLm.Auth.Guardian

  def put_auth_headers(conn, jwt) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", "Bearer #{jwt}")
  end

  def create_user_auth_conn(%{role: role} = claims) do
    {:ok, jwt, full_claims} = Guardian.encode_and_sign(claims, %{role: role})
    {:ok, claims} = Guardian.resource_from_claims(full_claims)

    conn =
      ConnTest.build_conn()
      |> put_auth_headers(jwt)

    {:ok, %{conn: conn, jwt: jwt, claims: claims}}
  end

  def create_claims(user_name, opts \\ []) do
    user_id = :rand.uniform(100_000)
    role = Keyword.get(opts, :role, "user")
    is_admin = role === "admin"

    %Claims{
      user_id: user_id,
      user_name: user_name,
      role: role,
      is_admin: is_admin
    }
  end
end
