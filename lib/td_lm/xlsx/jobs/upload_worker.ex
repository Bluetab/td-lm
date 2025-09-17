defmodule TdLm.XLSX.Jobs.UploadWorker do
  @moduledoc """
  An Oban worker responsible for processing XLSX file uploads.

  This worker is enqueued when an XLSX file is uploaded and executes
  the processing logic asynchronously using `TdLm.XLSX.RelationsUploader`.

  ## Functionality
  - Ensures uniqueness based on the job `hash`, preventing duplicate processing.
  - Processes uploaded XLSX files asynchronously via Oban.
  - Supports retry attempts (up to 5) in case of failures.
  - Extracts job options (`user_id`) before processing.
  """

  use Oban.Worker,
    queue: :xlsx_upload_queue,
    max_attempts: Application.get_env(:td_lm, :oban)[:attempts],
    unique: [
      fields: [:args, :worker],
      keys: [:hash],
      states: Oban.Job.states() -- [:cancelled, :discarded, :completed]
    ]

  require Logger

  alias TdLm.Auth.Claims
  alias TdLm.Resources
  alias TdLm.Xlsx.Reader
  alias TdLm.Xlsx.UploadEvents

  @impl Oban.Worker
  def perform(%Oban.Job{
        id: id,
        args: %{
          "relation_params" =>
            %{
              "path" => path,
              "filename" => filename,
              "hash" => hash
            } = relation_params,
          "opts" => opts
        },
        attempt: attempt,
        max_attempts: max
      }) do
    task_reference = "oban:#{id}"

    new_opts =
      opts
      |> Keyword.new(fn
        {"user_id", user_id} -> {:user_id, user_id}
        {"claims", claims} -> {:claims, Claims.coerce(claims)}
      end)
      |> Keyword.put(:task_reference, task_reference)

    create_init_event(attempt, task_reference, new_opts[:user_id], hash, filename)

    relation_params
    |> Reader.process_file(new_opts)
    |> Resources.bulk_create_relations(new_opts[:claims])
    |> then(fn
      {:ok, resume} = response ->
        UploadEvents.create_completed(
          resume,
          new_opts[:user_id],
          hash,
          filename,
          task_reference
        )

        File.rm!(path)
        response

      {:error, error} = response ->
        Logger.error("Error processing file: Invalid file, reason: #{inspect(error)}")

        if attempt == max do
          File.rm!(path)

          UploadEvents.create_failed(
            new_opts[:user_id],
            hash,
            filename,
            "Please contact Truedat's team: #{inspect(error)}",
            task_reference
          )
        end

        response
    end)
  end

  defp create_init_event(1, task_reference, user_id, hash, filename) do
    UploadEvents.create_started(user_id, hash, filename, task_reference)
  end

  defp create_init_event(attempt, task_reference, user_id, hash, filename) when attempt > 1 do
    UploadEvents.create_retrying(user_id, hash, filename, task_reference)
  end
end
