defmodule TdLm.Repo.Migrations.AddOban do
  use Ecto.Migration

  def up,
    do:
      Oban.Migration.up(
        prefix: Application.get_env(:td_lm, Oban)[:prefix],
        create_schema: Application.get_env(:td_lm, :oban_create_schema)
      )

  def down,
    do: Oban.Migration.down(prefix: Application.get_env(:td_lm, Oban)[:prefix], version: 1)
end
