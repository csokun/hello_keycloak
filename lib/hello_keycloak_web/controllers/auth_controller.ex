defmodule HelloKeycloakWeb.AuthController do
  @moduledoc """
  Auth controller responsible for handling Ueberauth responses
  """
  use HelloKeycloakWeb, :controller

  plug Ueberauth

  alias Ueberauth.Strategy.Keycloak

  def request(conn, _params) do
    redirect(conn, external: Keycloak.OAuth.authorize_url!())
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "You have been logged out!")
    |> clear_session()
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user = Map.merge(auth.info, %{user_id: auth.info.name})

    conn
    |> put_flash(:info, "Successfully authenticated.")
    |> HelloKeycloakWeb.UserAuth.log_in_user(user)
  end
end
