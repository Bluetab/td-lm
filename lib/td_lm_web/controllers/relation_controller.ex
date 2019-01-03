defmodule TdLmWeb.RelationController do
  use TdLmWeb, :controller

  alias TdLm.Resources
  alias TdLm.Resources.Relation

  action_fallback TdLmWeb.FallbackController

  def index(conn, _params) do
    relations = Resources.list_relations()
    render(conn, "index.json", relations: relations)
  end

  def create(conn, %{"relation" => relation_params}) do
    with {:ok, %Relation{} = relation} <- Resources.create_relation(relation_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", relation_path(conn, :show, relation))
      |> render("show.json", relation: relation)
    end
  end

  def show(conn, %{"id" => id}) do
    relation = Resources.get_relation!(id)
    render(conn, "show.json", relation: relation)
  end

  def update(conn, %{"id" => id, "relation" => relation_params}) do
    relation = Resources.get_relation!(id)

    with {:ok, %Relation{} = relation} <- Resources.update_relation(relation, relation_params) do
      render(conn, "show.json", relation: relation)
    end
  end

  def delete(conn, %{"id" => id}) do
    relation = Resources.get_relation!(id)
    with {:ok, %Relation{}} <- Resources.delete_relation(relation) do
      send_resp(conn, :no_content, "")
    end
  end
end
