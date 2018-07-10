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

    post "/business_concept/:business_concept_id/domain/:domain_id", LinkController, :add_field
    #   get("/fields/:concept_field_id", LinkController, :get_field)
    #   get("/fields", LinkController, :get_fields)
    #   post("/domain/:domain_id/fields", LinkController, :add_field)
    #   delete("/fields/:concept_field_id", LinkController, :delete_field)
    # end
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
