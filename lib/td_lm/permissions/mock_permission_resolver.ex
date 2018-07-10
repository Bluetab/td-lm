defmodule TdLm.Permissions.MockPermissionResolver do
  @moduledoc """
  Simple Mock Permission resolver.
  For the purpose of the test, I will assume that the user
  has not permissions if it is not an admin.
  The test of this functionality is meant to be in the module TdPerms
  """
  alias Poision

  def has_permission?(session_id, permission, resource_type, resource_id) do
    false
  end
end
