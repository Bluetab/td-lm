defmodule TdLmWeb.Router do
  use TdLmWeb, :router

  pipeline :api do
    plug(TdLm.Auth.Pipeline.Unsecure)
    plug(TdCore.I18n.Plug.Language)
    plug(:accepts, ["json"])
  end

  pipeline :api_auth do
    plug(TdLm.Auth.Pipeline.Secure)
    plug(TdCore.I18n.Plug.Language)
  end

  scope "/api", TdLmWeb do
    pipe_through(:api)
    get("/ping", PingController, :ping)
  end

  scope "/api", TdLmWeb do
    pipe_through([:api, :api_auth])

    resources "/relations", RelationController, except: [:new, :edit, :update]
    get "/relations/:resource_id/graph", GraphController, :graph
    post "/relations/search", RelationController, :search
    post "/relations/index_search", SearchController, :create
    post "/relations/filters", SearchController, :filters
    get "/relations/index_search/reindex_all", SearchController, :reindex_all
    post "/relations/status", BulkUpdateStatusController, :update, name: "status"
    resources "/tags", TagController, except: [:new, :edit]
    post "/tags/search", TagController, :search
    post "/relations/links/upload", XlsxController, :upload
  end
end
