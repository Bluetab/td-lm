defmodule TdLm.Repo.Migrations.ConceptFields do
  use Ecto.Migration

  def change do
    create table(:concept_fields) do
      add(:concept, :string)
      add(:field, :map)

      timestamps(type: :utc_datetime)
    end
  end
end
