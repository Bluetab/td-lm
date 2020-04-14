defmodule TdLmWeb.Router do
  use TdLmWeb, :router

  pipeline :api do
    plug(TdLm.Auth.Pipeline.Unsecure)
    plug(:accepts, ["json"])
  end

  pipeline :api_secure do
    plug(TdLm.Auth.Pipeline.Secure)
  end

  pipeline :api_authorized do
    plug(TdLm.Auth.CurrentResource)
    plug(Guardian.Plug.LoadResource)
  end

  scope "/api/swagger" do
    forward("/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :td_lm, swagger_file: "swagger.json")
  end

  scope "/api", TdLmWeb do
    pipe_through :api
    get "/ping", PingController, :ping
  end

  scope "/api", TdLmWeb do
    pipe_through([:api, :api_secure, :api_authorized])

    resources "/relations", RelationController, except: [:new, :edit]
    post "/relations/search", RelationController, :search
    resources "/tags", TagController, except: [:new, :edit]
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
