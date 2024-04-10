defmodule HelloKeycloakWeb.AuthController do
  @moduledoc """
  Auth controller responsible for handling Ueberauth responses
  """
  use HelloKeycloakWeb, :controller

  plug Ueberauth

  require Logger

  alias Ueberauth.Strategy.Keycloak

  def request(conn, _params) do
    redirect(conn, external: Keycloak.OAuth.authorize_url!())
  end

  def delete(conn, _params) do
    Logger.info("Logging out user")

    conn
    |> notify_keyclock_of_logout()
    |> HelloKeycloakWeb.UserAuth.log_out_user()
    |> put_flash(:info, "You have been logged out!")
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: ~p"/auth/unauthorized")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    # extract & store tokens
    # don't do this in production
    token = auth.credentials.token
    refresh_token = auth.credentials.refresh_token
    user = Map.merge(auth.info, %{user_id: auth.info.name})

    conn
    |> put_flash(:info, "Successfully authenticated.")
    |> HelloKeycloakWeb.UserAuth.log_in_user(user, token, refresh_token)
  end

  def unauthorized(conn, _params) do
    render(conn, "unauthorized.html")
  end

  defp notify_keyclock_of_logout(conn) do
    token = get_session(conn, :token)
    refresh_token = get_session(conn, :refresh_token)
    client_id = Application.get_env(:ueberauth, Ueberauth.Strategy.Keycloak.OAuth)[:client_id]

    client_secret =
      Application.get_env(:ueberauth, Ueberauth.Strategy.Keycloak.OAuth)[:client_secret]

    logout_url = "http://localhost:9000/realms/local/protocol/openid-connect/logout"

    body =
      "client_id=#{client_id}&client_secret=#{client_secret}&refresh_token=#{refresh_token}"

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    Req.post!(logout_url, body: body, headers: headers)

    conn
  end
end
