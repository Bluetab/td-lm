defmodule TdLm.Repo.Migrations.AlterRelationsSourceIdTargetIdType do
  use Ecto.Migration

  def change do
    execute("delete from relations where source_id !~ '^[0-9]+$' or target_id !~ '^[0-9]+$'", "")

    rename(table("relations"), :source_id, to: :_source_id_)
    rename(table("relations"), :target_id, to: :_target_id_)

    alter table("relations") do
      add(:source_id, :bigint)
      add(:target_id, :bigint)
    end

    execute(
      "update relations set source_id=_source_id_::bigint, target_id=_target_id_::bigint",
      "update relations set _source_id_=source_id::varchar(255), _target_id_=target_id::varchar(255)"
    )

    alter table("relations") do
      remove(:_source_id_, :string)
      remove(:_target_id_, :string)
    end
  end
end
