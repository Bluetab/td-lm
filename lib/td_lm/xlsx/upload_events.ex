defmodule TdLm.Xlsx.UploadEvents do
  @moduledoc """
  Module for handling upload events.

  This module provides functionality to:
  - Create upload events
  - Create upload events for failed uploads
  - Create upload events for retrying uploads
  """

  alias TdCluster.Cluster.TdBg

  def create_pending(user_id, hash, file_name, task_reference) do
    create_event(%{
      user_id: user_id,
      status: "PENDING",
      file_hash: hash,
      filename: file_name,
      task_reference: task_reference,
      node: Atom.to_string(Node.self())
    })
  end

  def create_retrying(user_id, hash, file_name, task_reference) do
    create_event(%{
      user_id: user_id,
      status: "RETRYING",
      file_hash: hash,
      filename: file_name,
      task_reference: task_reference,
      node: Atom.to_string(Node.self())
    })
  end

  def create_failed(user_id, hash, file_name, message, task_reference) do
    create_event(%{
      user_id: user_id,
      status: "FAILED",
      file_hash: hash,
      filename: file_name,
      message: message,
      task_reference: task_reference,
      node: Atom.to_string(Node.self())
    })
  end

  def create_started(user_id, hash, file_name, task_reference) do
    create_event(%{
      user_id: user_id,
      status: "STARTED",
      file_hash: hash,
      filename: file_name,
      task_reference: task_reference,
      node: Atom.to_string(Node.self())
    })
  end

  def create_completed(response, user_id, hash, file_name, task_reference) do
    create_event(%{
      response: response,
      user_id: user_id,
      file_hash: hash,
      filename: file_name,
      status: "COMPLETED",
      task_reference: task_reference,
      node: Atom.to_string(Node.self())
    })
  end

  defp create_event(event) do
    TdBg.create_bulk_upload_event(event)
  end
end
