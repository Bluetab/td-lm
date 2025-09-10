defmodule TdLmWeb.XlsxController do
  use TdHypermedia, :controller
  use TdLmWeb, :controller

  import Canada, only: [can?: 2]

  alias TdCore.Utils.FileHash
  alias TdLm.Resources.Relation
  alias TdLm.Xlsx.RelationsUploader
  alias TdLm.Xlsx.UploadEvents
  require Logger

  action_fallback(TdLmWeb.FallbackController)

  def upload(conn, %{"relations" => upload} = params) do
    %{user_id: user_id} = claims = conn.assigns[:current_resource]
    %{path: path, filename: filename} = upload

    opts = %{"user_id" => user_id, "claims" => claims}
    hash = FileHash.hash(path, :md5)

    relation_params =
      %{
        "source" => Map.get(params, "source"),
        "target" => Map.get(params, "target"),
        "path" => path,
        "filename" => filename,
        "hash" => hash
      }

    with {:params, true} <-
           {:params,
            not is_nil(relation_params["source"]) and not is_nil(relation_params["target"])},
         {:hash, true} <- {:hash, is_binary(hash)},
         {:can, true} <- {:can, can?(claims, create(Relation))},
         {:ok, %Oban.Job{id: oban_id}} <-
           RelationsUploader.upload_async(relation_params, hash, opts) do
      {status, file_hash, task_reference} =
        user_id
        |> UploadEvents.create_pending(hash, filename, "oban:#{oban_id}")
        |> process_event()

      conn
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(
        :accepted,
        Jason.encode!(%{status: status, file_hash: file_hash, task_reference: task_reference})
      )
    else
      {:params, false} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "missing_params"})

      error ->
        error
    end
  end

  defp process_event(
         {:ok, {:ok, %{status: status, file_hash: file_hash, task_reference: task_reference}}}
       ) do
    {status, file_hash, task_reference}
  end

  defp process_event(response) do
    Logger.error("Event failed #{inspect(response)}")
    {"EVENT_FAILED", nil, nil}
  end
end
