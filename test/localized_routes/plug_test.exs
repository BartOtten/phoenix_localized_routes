defmodule PhxLocalizedRoutes.PlugTest do
  use ExUnit.Case, async: true
  alias PhxLocalizedRoutes.Plug, as: P

  test "init returns it's opts" do
    assert P.init([1, 2, 3]) == [1, 2, 3]
  end

  test "conn with private assigns sets scope_helper in session" do
    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_private(:phx_loc_routes, %{assign: %{scope_helper: "test_helper"}})

    assert "test_helper" ==
             P.call(conn, [])
             |> Plug.Conn.fetch_session()
             |> Plug.Conn.get_session("scope_helper")
  end

  test "conn without private assigns returns original conn" do
    conn = Phoenix.ConnTest.build_conn()

    assert P.call(conn, []) == conn
  end
end
