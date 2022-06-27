defmodule PhxLocalizedRoutes.Fixtures.Assigns do
  defstruct [:key, locale: "en", opt_assign: "default"]
end

defmodule PhxLocalizedRoutes.Fixtures do
  alias PhxLocalizedRoutes.Scope
  alias __MODULE__.Assigns

  def scopes_with_map_assign,
    do: %{
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

  def scopes,
    do: %{
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

  def scopes_precomputed,
    do: %{
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

  def scopes_flat,
    do: %{
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
end
