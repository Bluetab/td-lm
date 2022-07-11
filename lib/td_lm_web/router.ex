defmodule TdLmWeb.Router do
  use TdLmWeb, :router

  pipeline :api do
    plug TdLm.Auth.Pipeline.Unsecure
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug TdLm.Auth.Pipeline.Secure
  end

  scope "/api/swagger" do
    forward("/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :td_lm, swagger_file: "swagger.json")
  end

  scope "/api", TdLmWeb do
    pipe_through :api
    get "/ping", PingController, :ping
  end

  scope "/api", TdLmWeb do
    pipe_through [:api, :api_auth]

    resources "/relations", RelationController, except: [:new, :edit, :update]
    get "/relations/:resource_id/graph", GraphController, :graph
    post "/relations/search", RelationController, :search
    resources "/tags", TagController, except: [:new, :edit, :update]
    post "/tags/search", TagController, :search
  end

  def swagger_info do
    %{
      schemes: ["http", "https"],
      info: %{
        version: "3.10",
        title: "Truedat Link Manager Service"
      },
      securityDefinitions: %{
        bearer: %{
          type: "apiKey",
          name: "Authorization",
          in: "header"
        }
      },
      security: [
        %{
          bearer: []
        }
      ]
    }
  end
end
