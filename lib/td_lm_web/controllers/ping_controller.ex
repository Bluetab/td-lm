defmodule TdLmWeb.PingController do
  use TdLmWeb, :controller

  action_fallback(TdLmWeb.FallbackController)

  def ping(conn, _params) do
    send_resp(conn, 200, "pong")
  end
end
