defmodule PhxLocalizedRoutesTest do
  use ExUnit.Case, async: true

  alias PhxLocalizedRoutes.Fixtures, as: F
  alias PhxLocalizedRoutes.Private, as: P

  require Logger

  @scopes_flat F.scopes_flat()

  describe "pre-compile function print_compile_header/3" do
    test "does not print a warning when no Gettext module is set" do
      Logger.flush()

      assert ExUnit.CaptureLog.capture_log(fn ->
               P.print_compile_header(TestRouter, false, %{
                 scopes: @scopes_flat
               })
             end) == ""
    end

    test "does not print a warning when auto compilation detected" do
      Logger.flush()

      assert ExUnit.CaptureLog.capture_log(fn ->
               P.print_compile_header(TestRouter, true, %{
                 gettext_module: MyAppWeb.Gettext,
                 scopes: @scopes_flat
               })
             end) == ""
    end

    test "prints a warning when a Gettext module is set and no auto compilation is detected" do
      Logger.flush()

      assert ExUnit.CaptureLog.capture_log(fn ->
               P.print_compile_header(TestRouter, false, %{
                 gettext_module: MyAppWeb.Gettext,
                 scopes: @scopes_flat
               })
             end) =~
               "When route translations are updated, run `mix compile --force TestRouter.Router`"
    end
  end
end

defmodule PhxLocalizedRoutesCompilationTest do
  use ExUnit.Case, async: true

  alias __MODULE__.LocRoutesConfig
  alias PhxLocalizedRoutes.Config
  alias PhxLocalizedRoutes.Fixtures, as: F
  alias PhxLocalizedRoutes.Scope

  require Logger

  @scopes_precomputed F.scopes_precomputed()
  @scopes_flat F.scopes_flat()

  try do
    defmodule LocRoutesConfig do
      alias PhxLocalizedRoutes.Fixtures.Assigns

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
  rescue
    e ->
      Logger.emergency(e.message)
      Logger.emergency("Cannot test compiled module as compilation failed")
      exit(:abort)
  end

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

  test "config returns a map with flattened and precomputed values" do
    assert LocRoutesConfig.config() == %Config{
             gettext_module: MyAppWeb.Gettext,
             scopes: @scopes_flat
           }
  end
end
