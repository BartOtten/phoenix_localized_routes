defmodule PhxLocalizedRoutes.HelpersTest do
  use ExUnit.Case, async: true

  alias MyAppWeb.MultiLangRouter.Helpers, as: OriginalRoutes
  alias MyAppWeb.MultiLangRouter.Helpers.Localized, as: Routes
  alias Phoenix.LiveView.Socket
  alias Plug.Conn
  alias PhxLocalizedRoutes.Helpers.Private, as: P

  require PhxLocalizedRoutes.Helpers
  require Logger

  @original "/products/11/edit"
  @localized "/europe/nl/producten/11/bewerken"

  test "loc_route/2 localizes a route" do
    conn = Phoenix.ConnTest.build_conn()
    scope_opts = MyAppWeb.MultiLangRoutes.scopes()["europe_nl"]
    assert MyAppWeb.NativeRouter.Helpers.product_index_path(conn, :edit, 11) == @original

    assert OriginalRoutes.product_index_path(conn, :edit, 11)
           |> PhxLocalizedRoutes.Helpers.loc_route(scope_opts) == @localized
  end

  test "loc_route/2 returns the original route when no scope is set" do
    conn = Phoenix.ConnTest.build_conn()
    scope_opts = MyAppWeb.MultiLangRoutes.scopes()[""]

    native = MyAppWeb.NativeRouter.Helpers.product_index_path(conn, :edit, 11)

    localized =
      conn
      |> OriginalRoutes.product_index_path(:edit, 11)
      |> PhxLocalizedRoutes.Helpers.loc_route(scope_opts)

    assert native == localized
  end

  test "localize_route/5 returns an error when a original function does not exist" do
    assert P.localize_route(OriginalRoutes, :product_index, [1, %{fail: true}], "my_scope") ==
             {:error, "Elixir.MyAppWeb.MultiLangRouter.Helpers.product_index does not exist"}
  end

  test "localize_route/5 returns an error when a original function does not accept the args" do
    # workaround for not detected exported functions
    apply(OriginalRoutes, :__info__, [:functions])

    assert P.localize_route(
             OriginalRoutes,
             :product_index_path,
             [1, 2, %{fail: true}],
             "my_scope"
           ) ==
             {:error,
              "Failed to apply Elixir.MyAppWeb.MultiLangRouter.Helpers.product_index_path() with [1, 2, %{fail: true}]"}
  end

  test "get_scope_helper/1 handles all formats" do
    assert P.get_scope_helper(%Socket{assigns: %{__assigns__: %{loc: %{scope_helper: "foo"}}}}) ==
             "foo"

    assert P.get_scope_helper(%Conn{assigns: %{loc: %{scope_helper: "bar"}}}) == "bar"
    assert P.get_scope_helper(%Conn{assigns: %{foo: :bar}}) == nil
  end

  test "helper_fn/2 returns the original helper when scope is nil" do
    assert P.helper_fn(:org_helper, nil) == :org_helper
  end

  test "helper_fn/2 returns the original helper when a non existing helper name is generated" do
    assert P.helper_fn(:org_helper, "non_existing_scope") == :org_helper
  end

  test "helper_fn/2 returns the stiched helper when scope is not empty and helper name exists" do
    assert P.helper_fn(:org_helper, "my_scoped") == :my_scoped_org_helper
  end

  test "fn_exists?/3 works as expected" do
    # workaround for not detected exported functions
    apply(Routes, :__info__, [:functions])

    assert P.fn_exists?(Routes, :europe_nl_product_index_path, [1]) == false
    assert P.fn_exists?(Routes, :europe_nl_product_index_path, [1, 2]) == true
    assert P.fn_exists?(Routes, :europe_nl_product_index_path, [1, 2, 3]) == true
    assert P.fn_exists?(Routes, :europe_nl_product_index_path, [1, 2, 3, 4]) == true
    assert P.fn_exists?(Routes, :europe_nl_product_index_path, [1, 2, 3, 4, 5]) == false
  end

  test "log_error/1 prints the given error" do
    Logger.flush()

    assert ExUnit.CaptureLog.capture_log(fn ->
             P.log_error("my error")
           end) =~ "my error"
  end
end
