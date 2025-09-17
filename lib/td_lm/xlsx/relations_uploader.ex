defmodule TdLm.Xlsx.RelationsUploader do
  @moduledoc """
  Module for handling XLSX file uploads containing relation data.

  This module provides functionality to:
  - Process XLSX files containing relation data asynchronously via Oban workers
  - Move uploaded files to a temporary location
  - Import and validate relation data from XLSX files
  - Create relations in bulk based on the imported data

  The module works with the following relation types:
  - Business concepts
  - Data structures
  - Tags
  - Domain external IDs
  """

  alias Oban
  alias TdLm.XLSX.Jobs.UploadWorker

  require Logger

  def upload_async(%{"path" => path, "filename" => filename} = relation_params, hash, opts) do
    file_path = move_to_tmp(path, filename, hash)

    %{
      relation_params: Map.put(relation_params, "path", file_path),
      opts: opts
    }
    |> UploadWorker.new()
    |> Oban.insert()
  end

  defp move_to_tmp(path, filename, hash) do
    upload_dir = uploads_tmp_folder()
    :ok = File.mkdir_p!(upload_dir)
    ext = Path.extname(filename)
    new_file_path = Path.join(upload_dir, "#{hash}#{ext}")

    :ok = File.cp!(path, new_file_path)

    new_file_path
  end

  defp uploads_tmp_folder do
    Application.get_env(:td_lm, :oban)[:uploads_tmp_folder]
  end
end
