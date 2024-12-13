defmodule TdLmWeb.TagController do
  use TdLmWeb, :controller

  import Canada, only: [can?: 2]

  alias TdLm.Resources
  alias TdLm.Resources.Tag

  action_fallback(TdLmWeb.FallbackController)

  def index(conn, params) do
    tags = Resources.list_tags(params)
    render(conn, "index.json", tags: tags)
  end

  def search(conn, params) do
    tags = Resources.list_tags(params)
    render(conn, "index.json", tags: tags)
  end

  def show(conn, %{"id" => id}) do
    tag = Resources.get_tag!(id)
    render(conn, "show.json", tag: tag)
  end

  def create(conn, %{"tag" => tag_params}) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, create_tag(%Tag{}))},
         {:ok, %{tag: tag}} <- Resources.create_tag(tag_params, claims) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.tag_path(conn, :show, tag))
      |> render("show.json", tag: tag)
    end
  end

  def update(conn, %{"id" => tag_id, "tag" => tag_params}) do
    claims = conn.assigns[:current_resource]

    with {:ok, tag} <- {:ok, Resources.get_tag(tag_id)},
         {:can, true} <- {:can, can?(claims, update_tag(tag))},
         {:ok, %{tag: tag}} <- Resources.update_tag(tag, tag_params, claims) do
      conn
      |> put_status(:ok)
      |> put_resp_header("location", Routes.tag_path(conn, :show, tag))
      |> render("show.json", tag: tag)
    end
  end

  def delete(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]
    tag = Resources.get_tag!(id)

    with {:can, true} <- {:can, can?(claims, delete_tag(tag))},
         {:ok, %{tag: _tag}} <- Resources.delete_tag(tag, claims) do
      send_resp(conn, :no_content, "")
    end
  end
end
