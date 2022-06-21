defmodule Router.Assigns do
  @moduledoc false
  defstruct [:contact, locale: "en"]
end

defmodule MyAppWeb.LocalizedRoutes do
  @moduledoc false
  alias Router.Assigns

  use PhxLocalizedRoutes,
    scopes: %{
      "/" => %{
        assign: %Assigns{contact: "root@example.com"},
        scopes: %{
          "/europe" => %{
            assign: %Assigns{
              contact: "europe@example.com"
            },
            scopes: %{
              "/nl" => %{
                assign: %Assigns{
                  locale: "nl",
                  contact: "verkoop@example.nl"
                }
              },
              "/be" => %{
                assign: %Assigns{
                  locale: "nl",
                  contact: "handel@example.be"
                }
              }
            }
          },
          "/gb" => %{
            assign: %Assigns{
              contact: "sales@example.com"
            }
          }
        }
      }
    }
end

defmodule MyAppWeb.MultiLangRoutes do
  @moduledoc false
  alias Router.Assigns

  use(
    PhxLocalizedRoutes,
    scopes: %{
      "/" => %{
        assign: %Assigns{contact: "root@example.com"},
        scopes: %{
          "/europe" => %{
            assign: %Assigns{contact: "europe@example.com"},
            scopes: %{
              "/nl" => %{
                assign: %Assigns{locale: "nl", contact: "verkoop@example.nl"}
              },
              "/be" => %{
                assign: %Assigns{locale: "nl", contact: "handel@example.be"}
              }
            }
          },
          "/gb" => %{assign: %Assigns{contact: "sales@example.com"}}
        }
      }
    },
    gettext_module: MyAppWeb.Gettext
  )
end
