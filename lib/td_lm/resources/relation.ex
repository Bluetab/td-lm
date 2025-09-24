defmodule TdLm.Resources.Relation do
  @moduledoc """
  Ecto Schema module for relations.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDfLib.Validation
  alias TdLm.Resources.Tag

  @valid_types [
    "business_concept",
    "data_field",
    "data_structure",
    "ingest",
    "implementation_ref"
  ]

  @valid_create_statuses ["pending"]

  @valid_update_statuses [
    "approved",
    "rejected"
  ]

  schema "relations" do
    field(:source_id, :integer)
    field(:source_type, :string)
    field(:target_id, :integer)
    field(:target_type, :string)
    field(:context, :map, default: %{})
    field(:origin, :string, default: nil)
    field(:deleted_at, :utc_datetime_usec)
    field(:status, :string, default: nil)
    field(:tags, {:array, :map}, virtual: true, default: [])
    belongs_to(:tag, Tag)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = relation, %{} = params) do
    relation
    |> cast(params, [
      :source_id,
      :source_type,
      :target_id,
      :target_type,
      :context,
      :status,
      :origin,
      :deleted_at,
      :tag_id
    ])
    |> validate_required([:source_id, :source_type, :target_id, :target_type, :context])
    |> validate_inclusion(:source_type, @valid_types)
    |> validate_inclusion(:target_type, @valid_types)
    |> validate_inclusion(:status, @valid_create_statuses)
    |> assoc_constraint(:tag)
    |> validate_change(:context, &Validation.validate_safe/2)
  end

  def status_changeset(%__MODULE__{} = relation, %{} = params) do
    relation
    |> cast(params, [:status])
    |> validate_inclusion(:status, @valid_update_statuses)
    |> validate_status_transition(relation)
  end

  defp validate_status_transition(
         %Ecto.Changeset{changes: changes} = changeset,
         %__MODULE__{status: old_status}
       ) do
    new_status = Map.get(changes, :status)

    case({old_status, new_status}) do
      {"pending", "approved"} ->
        changeset

      {"pending", "rejected"} ->
        changeset

      {nil, _} ->
        add_error(changeset, :status_nil, "is not allowed to change nil status")

      _ ->
        reason = String.to_atom("status_#{old_status}")
        add_error(changeset, reason, "is not allowed to change #{old_status} status")
    end
  end
end
