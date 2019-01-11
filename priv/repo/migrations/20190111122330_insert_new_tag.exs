defmodule TdLm.Repo.Migrations.InsertNewTag do
  use Ecto.Migration

  alias TdLm.Repo
  alias TdLm.Resources.Tag

  def change do    
    Repo.insert(%Tag{value: %{"type" => "business_concept_to_field_master"}})
  end
end
