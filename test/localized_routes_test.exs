defmodule My.Assigns do
  defstruct [:key, locale: "en", opt_assign: "default"]
end

# TODO: Move tests requiring compilation elsewhere
defmodule LocRoutesConfig do
  alias My.Assigns

  use PhxLocalizedRoutes,
    gettext_module: MyAppWeb.Gettext,
    scopes: %{
      "/" => %{
        assign: %Assigns{key: :root},
        scopes: %{
          "/foo" => %{
            assign: %Assigns{key: :root},
            scopes: %{
              "/nested" => %{
                assign: %Assigns{key: :n1},
                scopes: %{
                  "/nested2" => %{
                    assign: %Assigns{key: :n2}
                  }
                }
              }
            }
          }
        }
      }
    }
end

defmodule PhxLocalizedRoutesTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias PhxLocalizedRoutes.Exceptions.AssignsMismatchError
  alias PhxLocalizedRoutes.Exceptions.MissingLocaleAssignError
  alias PhxLocalizedRoutes.Exceptions.MissingRootSlugError
  alias PhxLocalizedRoutes.Private, as: P
  alias PhxLocalizedRoutes.Scope
  alias PhxLocalizedRoutes.Config

  alias My.Assigns

  @scopes_with_map_assign %{
    "/" => %{
      assign: %{key: :root, locale: "en", opt_assign: "default"},
      scopes: %{
        "/foo" => %{
          assign: %{
            locale: "en",
            key: :root
          },
          scopes: %{
            "/nested" => %{
              assign: %{key: :n1, locale: "en"},
              scopes: %{
                "/nested2" => %{assign: %{key: :n2, locale: "en"}}
              }
            }
          }
        }
      }
    }
  }

  @scopes %{
    "/" => %{
      assign: %Assigns{key: :root, locale: "en"},
      scopes: %{
        "/foo" => %{
          assign: %Assigns{
            locale: "en",
            key: :root
          },
          scopes: %{
            "/nested" => %{
              assign: %Assigns{key: :n1, locale: "en"},
              scopes: %{
                "/nested2" => %{assign: %Assigns{key: :n2, locale: "en"}}
              }
            }
          }
        }
      }
    }
  }

  @scopes_precomputed %{
    nil => %Scope.Nested{
      assign: %{scope_helper: nil, key: :root, locale: "en", opt_assign: "default"},
      scope_path: [],
      scope_alias: nil,
      scope_prefix: "/",
      scopes: %{
        "foo" => %Scope.Nested{
          assign: %{opt_assign: "default", locale: "en", key: :root, scope_helper: "foo"},
          scopes: %{
            "nested" => %Scope.Nested{
              assign: %{
                opt_assign: "default",
                locale: "en",
                key: :n1,
                scope_helper: "foo_nested"
              },
              scopes: %{
                "nested2" => %Scope.Nested{
                  assign: %{
                    opt_assign: "default",
                    locale: "en",
                    key: :n2,
                    scope_helper: "foo_nested_nested2"
                  },
                  scope_path: ["foo", "nested", "nested2"],
                  scope_alias: :nested2,
                  scope_prefix: "/nested2",
                  scopes: %{}
                }
              },
              scope_path: ["foo", "nested"],
              scope_alias: :nested,
              scope_prefix: "/nested"
            }
          },
          scope_path: ["foo"],
          scope_alias: :foo,
          scope_prefix: "/foo"
        }
      }
    }
  }

  @scopes_flat %{
    nil => %Scope.Flat{
      assign: %{scope_helper: nil, key: :root, locale: "en", opt_assign: "default"},
      scope_path: [],
      scope_alias: nil,
      scope_prefix: "/"
    },
    "foo" => %Scope.Flat{
      scope_path: ["foo"],
      assign: %{opt_assign: "default", locale: "en", key: :root, scope_helper: "foo"},
      scope_alias: :foo,
      scope_prefix: "/foo"
    },
    "foo_nested" => %Scope.Flat{
      scope_path: ["foo", "nested"],
      assign: %{opt_assign: "default", locale: "en", key: :n1, scope_helper: "foo_nested"},
      scope_alias: :foo_nested,
      scope_prefix: "/foo/nested"
    },
    "foo_nested_nested2" => %Scope.Flat{
      assign: %{
        opt_assign: "default",
        locale: "en",
        key: :n2,
        scope_helper: "foo_nested_nested2"
      },
      scope_path: ["foo", "nested", "nested2"],
      scope_alias: :foo_nested_nested2,
      scope_prefix: "/foo/nested/nested2"
    }
  }

  describe "test private functions" do
    test "validate opts raises on assign keys mismatch" do
      assert_raise AssignsMismatchError, fn ->
        P.validate_config!(%Config{
          scopes: %{
            nil => %{
              scope_prefix: "/",
              assign: %{key1: 1, key2: 2}
            },
            "foo" => %{assign: %{key1: 1}}
          }
        })
      end
    end

    test "validate opts does not raise when no assigns" do
      P.validate_config!(%Config{
        scopes: %{
          nil => %{
            scope_prefix: "/"
          },
          "foo" => %{}
        }
      })
    end

    test "validate opts does not raise when assign keys match" do
      matching_assign = %{key1: 1, key2: 2}

      P.validate_config!(%Config{
        scopes: %{
          nil => %{
            scope_prefix: "/",
            assign: matching_assign
          },
          "foo" => %{assign: matching_assign}
        }
      })
    end

    test "validate opts raises when no root slug is set" do
      assert_raise MissingRootSlugError, fn ->
        P.validate_config!(%{
          scopes: %{nil => %{scope_prefix: "foo", assign: %{key1: 1}}}
        })
      end
    end

    test "validate opts raises when gettext_module is set but no locale in assign" do
      assert_raise MissingLocaleAssignError, fn ->
        P.validate_config!(%Config{
          gettext_module: MyGettextModule,
          scopes: %{nil => %{scope_prefix: "/", assign: %{key1: 1}}}
        })
      end
    end

    test "validate opts does not raise when gettext_module is set and locale in assign" do
      P.validate_config!(%Config{
        gettext_module: MyGettextModule,
        scopes: %{nil => %{scope_prefix: "/", assign: %{locale: "de"}}}
      })
    end

    test "validate opts does not raise when gettext_module is set to nil" do
      P.validate_config!(%Config{
        gettext_module: nil,
        scopes: %{nil => %{scope_prefix: "/", assign: %{locale: "de"}}}
      })
    end

    test "add_precomputed_values!/1 with map assign adds precomputed values correctly" do
      assert P.add_precomputed_values!(@scopes_with_map_assign) == @scopes_precomputed
    end

    test "add_precomputed_values!/1 with struct assign adds precomputed values correctly" do
      assert P.add_precomputed_values!(@scopes) == @scopes_precomputed
    end

    test "flatten_scopes/1 returns a flat version of scopes scopes" do
      assert P.flatten_scopes(@scopes_precomputed) == @scopes_flat
    end

    test "print_compile_header does not print when no Gettext module is set or auto compilation detected" do
      assert ExUnit.CaptureLog.capture_log(fn ->
               P.print_compile_header(%{module: TestRouter}, false, %{
                 scopes: @scopes_flat
               })
             end) == ""
    end

    test "print_compile_header does print when a Gettext module is set and no auto compilation is detected" do
      assert ExUnit.CaptureLog.capture_log(fn ->
               P.print_compile_header(%{module: TestRouter}, false, %{
                 gettext_module: MyAppWeb.Gettext,
                 scopes: @scopes_flat
               })
             end) =~
               "When route translations are updated, run `mix compile --force TestRouter.Router`"
    end
  end

  describe "compiled module: " do
    @describetag :compiled

    test "using PhxLocalizedRoutes creates a module with helper functions" do
      assert Kernel.function_exported?(LocRoutesConfig.LiveHelpers, :on_mount, 4)
    end

    test "scopes_nested returns a nested map of scopes with precomputed values" do
      assert LocRoutesConfig.scopes_nested() == @scopes_precomputed
    end

    test "scopes returns a flat map of scopes scopes with precomputed values" do
      assert LocRoutesConfig.scopes() == @scopes_flat
    end

    test "get_scope/1 returns the configuration of given scope helper" do
      assert LocRoutesConfig.get_scope("foo_nested_nested2") == %Scope.Flat{
               assign: %{
                 key: :n2,
                 scope_helper: "foo_nested_nested2",
                 opt_assign: "default",
                 locale: "en"
               },
               scope_path: ["foo", "nested", "nested2"],
               scope_alias: :foo_nested_nested2,
               scope_prefix: "/foo/nested/nested2"
             }
    end

    test "assigned_values/1 returns a list of unique values when given a single key" do
      assert LocRoutesConfig.assigned_values(:opt_assign) == ["default"]
    end

    test "assigned_values/1 returns a list of unique value combinations when given a list of keys" do
      assert LocRoutesConfig.assigned_values([:key, :opt_assign]) == [
               {:n2, "default"},
               {:n1, "default"},
               {:root, "default"}
             ]
    end

    test "opts returns a map with flattened and precomputed values" do
      assert LocRoutesConfig.config() == %PhxLocalizedRoutes.Config{
               gettext_module: MyAppWeb.Gettext,
               scopes: @scopes_flat
             }
    end
  end
end

defmodule ConnectionTests do
  use ExUnit.Case, async: true
  use MyAppWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "Generated routes" do
    test "preserve native assigns", %{conn: conn} do
      conn = get(conn, "/europe/be/paginas/nieuw")
      assert Map.get(conn.assigns, :key) == :value
    end

    test "include configured assigns", %{conn: conn} do
      conn = get(conn, "/europe/be/paginas/nieuw")

      assert Map.get(conn.private, :phoenix_action) == :new
      assert Map.get(conn.private, :phoenix_controller) == MyAppWeb.PageController
      assert conn.path_info == ["europe", "be", "paginas", "nieuw"]

      assert Map.get(conn.assigns, :loc) == %{
               contact: "handel@example.be",
               locale: "nl",
               scope_helper: "europe_be"
             }
    end
  end

  describe "Normal Views and LiveViews" do
    test "share the same assigns", %{conn: conn} do
      conn = get(conn, "/europe/nl/producten")

      html = html_response(conn, 200)
      assert html =~ "Locale: nl"
      assert html =~ "Connected: false"
      assert html =~ "/europe/be/producten"

      {:ok, _view, html} = live(conn)
      assert html =~ "Locale: nl"
      assert html =~ "Connected: true"
      assert html =~ "/europe/be/producten"
    end

    test "render the correct links", %{conn: conn} do
      conn = get(conn, "/europe/nl/producten")

      html = html_response(conn, 200)

      assert html =~
               "<a data-phx-link=\"redirect\" data-phx-link-state=\"push\" href=\"/europe/nl/producten/nieuw\" id=\"redirect\">New Product</a>"

      assert html =~
               "<a data-phx-link=\"patch\" data-phx-link-state=\"push\" href=\"/europe/nl/producten/nieuw\" id=\"patch\">New Product</a>"

      assert html =~ "<a href=\"/europe/nl/producten/nieuw\" id=\"link\">New Product</a>"

      {:ok, _view, html} = live(conn)

      assert html =~
               "<a data-phx-link=\"redirect\" data-phx-link-state=\"push\" href=\"/europe/nl/producten/nieuw\" id=\"redirect\">New Product</a>"

      assert html =~
               "<a data-phx-link=\"patch\" data-phx-link-state=\"push\" href=\"/europe/nl/producten/nieuw\" id=\"patch\">New Product</a>"

      assert html =~ "<a href=\"/europe/nl/producten/nieuw\" id=\"link\">New Product</a>"
    end
  end

  describe "LiveViews" do
    test "redirect back to the localized route", %{conn: conn} do
      conn = get(conn, "/europe/nl/producten")
      {:ok, view, _html} = live(conn)

      assert view
             |> element("#patch")
             |> render_click() =~ "Modal"

      {:ok, modal_view, modal_html} = live(conn, "/europe/nl/producten/nieuw")
      assert modal_html =~ "Modal"

      modal_view
      |> element("form")
      |> render_submit(%{})

      assert_redirect(modal_view, "/europe/nl/producten", 30)
    end

    test "Can switch to root", %{conn: conn} do
      conn = get(conn, "/europe/nl/producten")

      html = html_response(conn, 200)

      assert html =~
               "<a href=\"/products\" id=\"link-\"> [] </a>"
    end
  end
end
