defmodule TdLmWeb.Router do
  use TdLmWeb, :router

  pipeline :api do
    plug TdLm.Auth.Pipeline.Unsecure
    plug :accepts, ["json"]
  end

  pipeline :api_secure do
    plug TdLm.Auth.Pipeline.Secure
  end

  pipeline :api_authorized do
    plug TdLm.Auth.CurrentUser
    plug Guardian.Plug.LoadResource
  end

  scope "/api/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :td_lm, swagger_file: "swagger.json"
  end

  scope "/api", TdLmWeb do
    pipe_through [:api, :api_secure, :api_authorized]
    # resources "/business_concept", LinkController, except: [:new, :edit, :update] do
  end
end
