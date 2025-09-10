defmodule TdLm.Factory do
  @moduledoc """
  An `ExMachina` factory for link manager tests.
  """

  use ExMachina.Ecto, repo: TdLm.Repo
  use TdDfLib.TemplateFactory

  def relation_factory(attrs) do
    %TdLm.Resources.Relation{
      source_type:
        sequence(:source_or_target_type, [
          "business_concept",
          "data_field",
          "data_structure",
          "ingest"
        ]),
      source_id: sequence(:source_id, & &1),
      target_type:
        sequence(:source_or_target_type, [
          "business_concept",
          "data_field",
          "data_structure",
          "ingest"
        ]),
      target_id: sequence(:target_id, & &1),
      origin: nil,
      tag: build(:tag)
    }
    |> merge_attributes(attrs)
  end

  def tag_factory do
    %TdLm.Resources.Tag{
      value: %{
        "type" =>
          sequence(:source_or_target_type, [
            "business_concept",
            "data_field",
            "implementation",
            "data_structure",
            "ingest"
          ]),
        "target_type" =>
          sequence(:source_or_target_type, [
            "business_concept",
            "data_field",
            "implementation",
            "data_structure",
            "ingest"
          ])
      }
    }
  end

  def claims_factory(attrs) do
    %TdLm.Auth.Claims{
      user_id: sequence(:user_id, & &1),
      user_name: sequence("user_name"),
      role: "user",
      jti: sequence("jti"),
      exp: DateTime.add(DateTime.utc_now(), 10)
    }
    |> merge_attributes(attrs)
  end

  def domain_factory(attrs) do
    %{
      name: sequence("domain_name"),
      id: System.unique_integer([:positive]),
      external_id: sequence("domain_external_id"),
      updated_at: DateTime.utc_now()
    }
    |> merge_attributes(attrs)
  end

  def business_concept_factory(attrs) do
    %{
      id: System.unique_integer([:positive]),
      versions: [
        %{
          name: sequence("concept_name"),
          status: "published",
          version: 1,
          content: %{}
        }
      ]
    }
    |> merge_attributes(attrs)
  end

  def business_concept_version_factory(attrs) do
    %{
      id: System.unique_integer([:positive]),
      business_concept: %{
        id: System.unique_integer([:positive]),
        versions: [
          %{
            name: sequence("concept_name"),
            status: "published",
            version: 1,
            content: %{}
          }
        ]
      }
    }
    |> merge_attributes(attrs)
  end

  def data_structure_factory(attrs) do
    %{
      id: System.unique_integer([:positive]),
      name: sequence("structure_name"),
      content: %{},
      external_id: sequence("ds_external_id"),
      latest_version: %{
        deleted_at: nil
      }
    }
    |> merge_attributes(attrs)
  end

  def implementation_factory(attrs) do
    implementation_ref = System.unique_integer([:positive])

    %{
      id: implementation_ref,
      name: sequence("implementation_name"),
      content: %{},
      implementation_ref: implementation_ref,
      deleted_at: nil
    }
    |> merge_attributes(attrs)
  end

  def user_factory do
    %{
      id: System.unique_integer([:positive]),
      user_name: sequence("user_name"),
      full_name: sequence("full_name"),
      external_id: sequence("user_external_id"),
      email: sequence("email") <> "@example.com"
    }
  end
end
