defmodule TdLmWeb.Router do
  use TdLmWeb, :router

  @endpoint_url "#{Application.get_env(:td_lm, TdLmWeb.Endpoint)[:url][:host]}:#{Application.get_env(:td_lm, TdLmWeb.Endpoint)[:url][:port]}"

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
    resources "/business_concept", LinkController, except: [:new, :edit, :update] do
      get    "/fields/:concept_field_id", LinkController, :get_field
      get    "/fields", LinkController, :get_fields
      post   "/fields", LinkController, :add_field
      delete "/fields/:concept_field_id", LinkController, :delete_field
    end
  end
end
