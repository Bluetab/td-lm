defmodule TdLm.Auth.Pipeline.Secure do
  @moduledoc """
  Plug pipeline for routes requiring authentication
  """

  use Guardian.Plug.Pipeline,
    otp_app: :td_lm,
    error_handler: TdLm.Auth.ErrorHandler,
    module: TdLm.Auth.Guardian

  plug Guardian.Plug.EnsureAuthenticated, claims: %{"aud" => "truedat", "iss" => "tdauth"}
  plug Guardian.Plug.LoadResource
  plug TdLm.Auth.Plug.SessionExists
  plug TdLm.Auth.Plug.CurrentResource
end
