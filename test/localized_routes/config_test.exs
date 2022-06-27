defmodule PhxLocalizedRoutes.ConfigTest do
  use ExUnit.Case

  alias PhxLocalizedRoutes.Config
  alias PhxLocalizedRoutes.Scopes
  alias PhxLocalizedRoutes.Exceptions.AssignsMismatchError
  alias PhxLocalizedRoutes.Exceptions.MissingLocaleAssignError
  alias PhxLocalizedRoutes.Exceptions.MissingRootSlugError

  describe "config new" do
    test "returns a Config struct" do
      scopes_nested =
        Scopes.add_precomputed_values!(%{
          "/" => %{
            assign: %{key1: 1, key2: 2},
            scopes: %{
              "/foo" => %{assign: %{key1: 1, key2: 2}}
            }
          }
        })

      assert %Config{scopes: %{nil => _, "foo" => _}} = Config.new!(scopes_nested: scopes_nested)
    end
  end

  describe "config validation" do
    test "raises on assign keys mismatch" do
      assert_raise AssignsMismatchError, fn ->
        Config.validate!(%Config{
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

    test "does not raise when no assigns" do
      config = %Config{
        scopes: %{
          nil => %{
            scope_prefix: "/"
          },
          "foo" => %{}
        }
      }

      assert config == Config.validate!(config)
    end

    test "does not raise when assign keys match" do
      matching_assign = %{key1: 1, key2: 2}

      config = %Config{
        scopes: %{
          nil => %{
            scope_prefix: "/",
            assign: matching_assign
          },
          "foo" => %{assign: matching_assign}
        }
      }

      assert config == Config.validate!(config)
    end

    test "raises when no root slug is set" do
      assert_raise MissingRootSlugError, fn ->
        Config.validate!(%Config{
          scopes: %{nil => %{scope_prefix: "foo", assign: %{key1: 1}}}
        })
      end
    end

    test "raises when gettext_module is set but no locale in assign" do
      assert_raise MissingLocaleAssignError, fn ->
        Config.validate!(%Config{
          gettext_module: MyGettextModule,
          scopes: %{nil => %{scope_prefix: "/", assign: %{key1: 1}}}
        })
      end
    end

    test "does not raise when gettext_module is set and locale in assign" do
      Config.validate!(%Config{
        gettext_module: MyGettextModule,
        scopes: %{nil => %{scope_prefix: "/", assign: %{locale: "de"}}}
      })
    end

    test "does not raise when gettext_module is set to nil" do
      Config.validate!(%Config{
        gettext_module: nil,
        scopes: %{nil => %{scope_prefix: "/", assign: %{locale: "de"}}}
      })
    end
  end
end
