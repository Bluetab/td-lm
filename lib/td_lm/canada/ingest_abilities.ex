defmodule TdLm.Canada.IngestAbilities do
  @moduledoc false
  alias TdLm.Auth.Claims
  alias TdLm.Permissions

  @view_ingest [
    :view_approval_pending_ingests,
    :view_deprecated_ingests,
    :view_draft_ingests,
    :view_published_ingests,
    :view_rejected_ingests,
    :view_versioned_ingests
  ]

  def can?(%Claims{} = claims, :search, %{resource_id: id, resource_type: "ingest"}) do
    Permissions.authorized_any?(claims, @view_ingest, "ingest", id)
  end

  def can?(%Claims{} = claims, :show, %{resource_id: id, resource_type: "ingest"}) do
    Permissions.authorized_any?(claims, @view_ingest, "ingest", id)
  end

  def can?(%Claims{} = claims, :update, %{resource_id: id, resource_type: "ingest"}) do
    Permissions.authorized?(claims, :manage_ingest_relations, "ingest", id)
  end

  def can?(%Claims{} = claims, :create, %{resource_id: id, resource_type: "ingest"}) do
    Permissions.authorized?(claims, :manage_ingest_relations, "ingest", id)
  end

  def can?(%Claims{} = claims, :delete, %{resource_id: id, resource_type: "ingest"}) do
    Permissions.authorized?(claims, :manage_ingest_relations, "ingest", id)
  end

  def can?(%Claims{}, _permission, _params) do
    false
  end
end
