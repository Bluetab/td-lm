defmodule TdLm.Canada.IngestAbilities do
  @moduledoc false
  alias TdLm.Accounts.User
  alias TdLm.Permissions

  @view_ingest [
    :view_approval_pending_ingests,
    :view_deprecated_ingests,
    :view_draft_ingests,
    :view_published_ingests,
    :view_rejected_ingests,
    :view_versioned_ingests
  ]

  def can?(%User{} = user, :search, %{resource_id: id, resource_type: "ingest"}) do
    Permissions.authorized_any?(user, @view_ingest, "ingest", id)
  end

  def can?(%User{} = user, :show, %{resource_id: id, resource_type: "ingest"}) do
    Permissions.authorized_any?(user, @view_ingest, "ingest", id)
  end

  def can?(%User{} = user, :update, %{resource_id: id, resource_type: "ingest"}) do
    Permissions.authorized?(user, :manage_ingest_relations, "ingest", id)
  end

  def can?(%User{} = user, :create, %{resource_id: id, resource_type: "ingest"}) do
    Permissions.authorized?(user, :manage_ingest_relations, "ingest", id)
  end

  def can?(%User{} = user, :delete, %{resource_id: id, resource_type: "ingest"}) do
    Permissions.authorized?(user, :manage_ingest_relations, "ingest", id)
  end

  def can?(%User{} = _user, _permission, _params) do
    false
  end
end
