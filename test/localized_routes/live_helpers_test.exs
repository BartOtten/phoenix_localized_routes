defmodule PhxLocalizedRoutes.LiveHelpersTest do
  use ExUnit.Case, async: true
  alias Phoenix.LiveView.Socket
  alias PhxLocalizedRoutes.LiveHelpers
  alias MyAppWeb.MultiLangRoutes

  @scope MultiLangRoutes.scopes()["europe_nl"]

  test "on_mount/4 sets assigns from private assigns" do
    assigns = @scope.assign

    assert {
             :cont,
             %Phoenix.LiveView.Socket{
               assigns: %{
                 __changed__: %{loc: true},
                 loc: ^assigns
               }
             }
           } =
             LiveHelpers.on_mount(MultiLangRoutes, %{}, %{}, %Socket{
               private: %{
                 connect_info: %{
                   private: %{
                     phx_loc_routes: %{assign: @scope.assign}
                   }
                 }
               }
             })
  end

  test "on_mount/4 sets assigns from session" do
    assigns = @scope.assign

    assert {
             :cont,
             %Phoenix.LiveView.Socket{
               assigns: %{
                 __changed__: %{loc: true},
                 loc: ^assigns
               }
             }
           } =
             LiveHelpers.on_mount(
               MultiLangRoutes,
               %{},
               %{"scope_helper" => "europe_nl"},
               %Socket{}
             )
  end

  test "on_mount/4 assigns using session or private assigns are equal" do
    {:cont, session} =
      LiveHelpers.on_mount(
        MultiLangRoutes,
        %{},
        %{"scope_helper" => "europe_nl"},
        %Socket{}
      )

    {:cont, private} =
      LiveHelpers.on_mount(MultiLangRoutes, %{}, %{}, %Socket{
        private: %{
          connect_info: %{private: %{phx_loc_routes: %{assign: @scope.assign}}}
        }
      })

    assert session.assigns == private.assigns
  end
end
