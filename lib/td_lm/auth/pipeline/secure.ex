defmodule TdLm.Auth.Pipeline.Secure do
  @moduledoc false
  use Guardian.Plug.Pipeline,
    otp_app: :td_lm,
    error_handler: TdLm.Auth.ErrorHandler,
    module: TdLm.Auth.Guardian

  plug Guardian.Plug.EnsureAuthenticated
  plug TdLm.Auth.CurrentResource
end
