defmodule TdLm.Factory do
  @moduledoc """
  An `ExMachina` factory for link manager tests.
  """

  use ExMachina.Ecto, repo: TdLm.Repo

  def relation_factory do
    %TdLm.Resources.Relation{
      source_type: sequence(:source_or_target_type, ["business_concept", "data_field", "data_structure", "ingest"]),
      source_id: sequence(:source_id, & &1),
      target_type: sequence(:source_or_target_type, ["business_concept", "data_field", "data_structure", "ingest"]),
      target_id: sequence(:target_id, & &1),
      tags: []
    }
  end

  def tag_factory do
    %TdLm.Resources.Tag{
      value: %{
        "type" => sequence(:source_or_target_type, ["business_concept", "data_field", "data_structure", "ingest"]),
        "target_type" => sequence(:source_or_target_type, ["business_concept", "data_field", "data_structure", "ingest"]),
      }
    }
  end

  def claims_factory(attrs) do
    %TdLm.Auth.Claims{
      user_id: sequence(:user_id, & &1),
      user_name: sequence("user_name"),
      role: "user",
      jti: sequence("jti"),
      is_admin: Map.get(attrs, :role) == "admin"
    }
    |> merge_attributes(attrs)
  end
end
