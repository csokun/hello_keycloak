defmodule HelloKeycloakWeb.UserAuth do
  use HelloKeycloakWeb, :verified_routes
  import Plug.Conn
  import Phoenix.Controller

  alias Phoenix.LiveView
  alias HelloKeycloakWeb.Endpoint

  def on_mount(:current_user, _params, session, socket) do
    case session do
      %{"user_id" => user_id} ->
        {:cont,
         Phoenix.Component.assign_new(socket, :current_user, fn ->
           # get user details
           %{"user_id" => user_id}
         end)}

      %{} ->
        {:cont, Phoenix.Component.assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    case session do
      %{"user_id" => user_id} ->
        new_socket =
          Phoenix.Component.assign_new(socket, :current_user, fn ->
            %{"user_id" => user_id}
          end)

        {:cont, new_socket}

      %{} ->
        {:halt, redirect_require_login(socket)}
    end
  rescue
    Ecto.NoResultsError -> {:halt, redirect_require_login(socket)}
  end

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_user(conn, user) do
    user_return_to = get_session(conn, :user_return_to)
    conn = assign(conn, :current_user, user)

    conn
    |> renew_session()
    |> put_session(:user_id, user.user_id)
    |> put_session(:live_socket_id, "users_sessions:#{user.user_id}")
    |> redirect(to: user_return_to || ~p"/")
  end

  defp renew_session(conn) do
    # TODO: refresh token?
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    if live_socket_id = get_session(conn, :live_socket_id) do
      Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> redirect(to: ~p"/auth/keycloak")
  end

  @doc """
  Authenticates the user by looking into the session.
  """
  def fetch_current_user(conn, _opts) do
    case get_session(conn, :user_id) do
      nil ->
        conn

      user_id ->
        conn
        |> assign(:current_user, %{"user_id" => user_id})
    end
  end

  @doc """
  Used for routes that require the user to not be authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: ~p"/")
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the user to be authenticated.

  If you want to enforce the user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: ~p"/auth/keycloak")
      |> halt()
    end
  end

  defp redirect_require_login(socket) do
    socket
    |> LiveView.put_flash(:error, "Please sign in")
    |> LiveView.redirect(to: ~p"/auth/keycloak")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    %{request_path: request_path, query_string: query_string} = conn
    return_to = if query_string == "", do: request_path, else: request_path <> "?" <> query_string
    put_session(conn, :user_return_to, return_to)
  end

  defp maybe_store_return_to(conn), do: conn
end
