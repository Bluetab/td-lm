defmodule TdLm.Permissions do
  @moduledoc """
  The Permissions context.
  """

  import Ecto.Query, warn: false

  alias TdLm.Accounts.User

  @permission_resolver Application.get_env(:td_lm, :permission_resolver)

  @doc """
  Check if user has a permission in a domain.

  ## Examples

      iex> authorized?(%User{}, "create", 12)
      false

  """
  def authorized?(%User{jti: jti}, permission, resource_type, id) do
    @permission_resolver.has_permission?(jti, permission, resource_type, id)
  end

end
