defmodule TdLm.Search.Indexer do
  @moduledoc """
  Indexer for Concepts.
  """

  alias TdCore.Search.IndexWorker

  @index :relations

  def reindex(ids) do
    IndexWorker.reindex(@index, ids)
  end

  def delete(ids) do
    IndexWorker.delete(@index, ids)
  end
end
