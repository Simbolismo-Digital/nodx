defmodule NodxWeb.PageController do
  use NodxWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
