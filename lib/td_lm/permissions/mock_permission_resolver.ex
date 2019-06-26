defmodule TdLm.Permissions.MockPermissionResolver do
  @moduledoc """
  Simple Mock Permission resolver.
  For the purpose of the test, I will assume that the user
  has not permissions if it is not an admin.
  The test of this functionality is meant to be in the module TdCache
  """
  alias Poision

  def has_permission?(_session_id, _permission, _resource_type, _resource_id) do
    false
  end

  def has_any_permission?(_session_id, _permission, _resource_type, _resource_id) do
    false
  end

end
