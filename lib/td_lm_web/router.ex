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
    plug(TdLm.Auth.CurrentUser)
    plug(Guardian.Plug.LoadResource)
  end

  scope "/api/swagger" do
    forward("/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :td_lm, swagger_file: "swagger.json")
  end

  scope "/api", TdLmWeb do
    pipe_through([:api, :api_secure, :api_authorized])

    post "/:resource_type/:resource_id/links", LinkController, :add_link
    get "/:resource_type/:resource_id/links", LinkController, :get_links
    get "/:resource_type/:resource_id/links/:field_id", LinkController, :get_link
    delete "/:resource_type/:resource_id/links/:field_id", LinkController, :delete_link
  end

  def swagger_info do
    %{
      schemes: ["http"],
      info: %{
        version: "1.0",
        title: "TdLm"
      },
      host: @endpoint_url,
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
