defmodule TdLmWeb.BulkUpdateStatusController do
  use TdLmWeb, :controller

  import Canada, only: [can?: 2]

  alias TdLm.Resources
  alias TdLm.Resources.Relation

  action_fallback(TdLmWeb.FallbackController)

  def update(conn, params) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, update_status(Relation))},
         {:ok, update_results} <-
           Resources.update_relations_status(params, claims) do
      conn
      |> put_status(:ok)
      |> render("update_status.json", update_results: update_results)
    end
  end
end
