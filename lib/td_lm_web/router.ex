defmodule TdLmWeb.Router do
  use TdLmWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", TdLmWeb do
    pipe_through :api
  end
end
