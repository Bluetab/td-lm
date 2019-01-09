defmodule TdLmWeb.Router do
  use TdLmWeb, :router

  @endpoint_url "#{Application.get_env(:td_lm, TdLmWeb.Endpoint)[:url][:host]}:#{
                  Application.get_env(:td_lm, TdLmWeb.Endpoint)[:url][:port]
                }"

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
    get  "/ping", PingController, :ping
  end

  scope "/api", TdLmWeb do
    pipe_through([:api, :api_secure, :api_authorized])

    post "/:resource_type/:resource_id/links", LinkController, :add_link
    get "/:resource_type/:resource_id/links", LinkController, :get_links
    get "/:resource_type/:resource_id/links/:id", LinkController, :get_link
    delete "/:resource_type/:resource_id/links/:id", LinkController, :delete_link
    get "/links", LinkController, :index

    resources "/relations", RelationController, except: [:new, :edit]
    resources "/tags", TagController, except: [:new, :edit]
  end

  def swagger_info do
    %{
      schemes: ["http"],
      info: %{
        version: "1.0",
        title: "TdLm"
      },
      host: @endpoint_url,
      basePath: "/api",
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
