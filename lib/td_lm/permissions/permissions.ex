defmodule TdLm.Permissions do
  @moduledoc """
  The Permissions context.
  """

  import Ecto.Query, warn: false

  alias TdLm.Auth.Claims

  def authorized?(%{jti: jti}, permission, resource_ids)
      when is_list(resource_ids) do
    TdCache.Permissions.has_permission?(jti, permission, "domain", resource_ids)
  end

  def authorized?(%Claims{jti: jti}, permission, resource_type, id) do
    TdCache.Permissions.has_permission?(jti, permission, resource_type, id)
  end

  def authorized_any?(%Claims{jti: jti}, permissions, resource_type, id) do
    TdCache.Permissions.has_any_permission?(jti, permissions, resource_type, id)
  end

  def has_any_permission?(%Claims{jti: jti}, permissions) do
    TdCache.Permissions.has_any_permission?(jti, permissions)
  end
end
