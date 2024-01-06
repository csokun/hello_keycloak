defmodule HelloKeycloakWeb.PageController do
  use HelloKeycloakWeb, :controller

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end
end
