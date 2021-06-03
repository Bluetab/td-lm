defmodule TdLm.Permissions do
  @moduledoc """
  The Permissions context.
  """

  import Ecto.Query, warn: false

  alias TdLm.Auth.Claims

  @permission_resolver Application.compile_env(:td_lm, :permission_resolver)

  @doc """
  Check if authenticated user has a permission in a domain.

  ## Examples

      iex> authorized?(%Claims{}, :create, "business_concept", 12)
      false

  """
  def authorized?(%Claims{jti: jti}, permission, resource_type, id) do
    @permission_resolver.has_permission?(jti, permission, resource_type, id)
  end

  @doc """
  Check if authenticated user has a any permission in a domain.

  ## Examples

      iex> authorized_any?(%Claims{}, [:create, :delete], "business_concept", 12)
      false

  """
  def authorized_any?(%Claims{jti: jti}, permissions, resource_type, id) do
    @permission_resolver.has_any_permission?(jti, permissions, resource_type, id)
  end
end
