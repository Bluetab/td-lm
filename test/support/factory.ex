defmodule TdLm.Factory do
  @moduledoc """
  An `ExMachina` factory for link manager tests.
  """

  use ExMachina.Ecto, repo: TdLm.Repo

  def relation_factory do
    %TdLm.Resources.Relation{
      source_type: "source_type",
      source_id: sequence("source_id"),
      target_type: "target_type",
      target_id: sequence("target_id"),
      tags: []
    }
  end

  def tag_factory do
    %TdLm.Resources.Tag{
      value: %{
        "type" => sequence("source_type"),
        "target_type" => sequence("source_type")
      }
    }
  end

  def user_factory do
    %{
      id: sequence(:user_id, & &1)
    }
  end
end
