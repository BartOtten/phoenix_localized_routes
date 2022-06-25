defmodule PhxLocalizedRoutes.RouterTest do
  use ExUnit.Case, asyc: true
  import ListAssertions
  import RouterTestHelpers

  # Routers
  alias MyAppWeb.LocRouter
  alias MyAppWeb.MultiLangRouter
  alias MyAppWeb.NativeRouter

  # Private module
  alias PhxLocalizedRoutes.Router.Private, as: P

  @scopes [
    {"", ""},
    {"gb_", "/gb"},
    {"europe_", "/europe"},
    {"europe_nl_", "/europe/nl"},
    {"europe_be_", "/europe/be"}
  ]

  @native_routes for route <- Phoenix.Router.routes(NativeRouter), do: comparable_route(route)
  @scoped_routes for route <- Phoenix.Router.routes(LocRouter), do: comparable_route(route)
  @multi_routes for route <- Phoenix.Router.routes(MultiLangRouter), do: comparable_route(route)

  @expected_routes (for %{helper: helper, path: path} = route <- @native_routes,
                        {scope, slug} <- @scopes do
                      helper = if is_nil(helper), do: nil, else: "#{scope}#{helper}"

                      %{
                        route
                        | helper: helper,
                          path: Path.join(["/", slug, path])
                      }
                    end)

  use Phoenix.Router
  import Phoenix.LiveView.Router
  import PhxLocalizedRoutes.Router

  # TODO: write proper test
  localize(MyAppWeb.MultiLangRoutes, [opts: MyAppWeb.MultiLangRoutes.opts()],
    do: get("/paginas/nieuw", MyAppWeb.PageController, :new)
  )

  test "after_routes_callback does not raise" do
    assert nil == P.after_routes_callback(%Macro.Env{module: MultiLangRouter}, <<>>)
    assert Code.ensure_compiled!(MyAppWeb.MultiLangRouter.Helpers.Localized)
  end

  test "Localize multilang routes" do
    P.do_localize(
      MyAppWeb.MultiLangRoutes,
      [],
      quote do
        get("/users/register", UserController, :new)
        post("/users/register", UserController, :create)
        put("/users/settings", UserController, :update)
        delete("/users/log_out", UserController, :delete)
        live("/", HomeLive, :index)
        live("/products/:id/edit", ProductLive.Index, :edit)
        live("/wildcard/*", WildcardController)
      end
    )
  end

  test "Localize routes" do
    P.do_localize(
      MyAppWeb.LocalizedRoutes,
      [],
      quote do
        get("/users/register", UserController, :new)
        post("/users/register", UserController, :create)
        put("/users/settings", UserController, :update)
        delete("/users/log_out", UserController, :delete)
        live("/", HomeLive, :index)
        live("/products/:id/edit", ProductLive.Index, :edit)
        live("/wildcard/*", WildcardController)
      end
    )
  end

  test "Localize single route (non block)" do
    P.do_localize(
      MyAppWeb.LocalizedRoutes,
      [],
      quote(do: get("/users/register", UserController, :new))
    )
  end

  test "routes are expanded" do
    pattern_ast =
      quote do
        unquote(Macro.escape(@expected_routes))
      end

    Code.eval_quoted(
      quote do
        assert_unordered(unquote(pattern_ast), unquote(Macro.escape(@scoped_routes)))
      end
    )
  end

  test "routes are translated" do
    translated_routes = @multi_routes -- @scoped_routes
    assert Enum.count(translated_routes) == 38

    assert Enum.filter(translated_routes, &(&1.path == "/europe/be/producten/nieuw"))
           |> length() == 1
  end

  test "shortest helper is returned" do
    assert P.shortest_helper(["eu_foo", "foo", "be_foo"]) == "foo"
  end
end
