# Usage

## Installation

You can install this library by adding it to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_localized_routes, "~> 0.1.0"}
  ]
end
```

We pressed on making the installation as non-intrusive as possible; yet a few files have to be modified or created.

## Helpers
`Phoenix Localized Routes` adds localization to the helpers created by Phoenix; no code changes in controllers and (live)views necessary.

```elixir
# file: lib/example_web/example_web.ex

# in controller
-  alias ExampleWeb.Router.Helpers, as: Routes
+  unquote(loc_helpers())

# in live_view
+  on_mount(ExampleWeb.LocalizedRoutes.LiveHelpers)

# in router
+  import PhxLocalizedRoutes.Router
+  use PhxLocalizedRoutes.Router

# in view_helpers
-  alias ExampleWeb.Router.Helpers, as: Routes
+  unquote(loc_helpers())

# insert new private function
+  defp loc_helpers do
+    quote do
+      import PhxLocalizedRoutes.Helpers
+      alias ExampleWeb.Router.Helpers, as: OriginalRoutes
+      alias ExampleWeb.Router.Helpers.Localized, as: Routes
+      alias ExampleWeb.LocalizedRoutes, as: Loc
+    end
+  end
```


```elixir
# file: lib/example_web/router.ex

# Add to browser pipeline
+   plug(PhxLocalizedRoutes.Plug)
```

## Configuration

Create the module `[MyAppWeb].LocalizedRoutes` in the directory of your web application. The example shows a nested configuration using the default `[MyAppWeb].Gettext` module for multilingual URL's.

It is possible to set:

  * `:scopes` - scopes as map of maps, the keys are used as URL segments (slugs).
  * `:gettext_module` - `Gettext` module to extract URL segments and translate them.

For each local scope you can set.

  * `:assign` - a `Map` or `Struct` of values to assign to the `Plug.Conn` and/or `Phoenix.Socket`. When using a `Map` nested scopes inherit assigns from their parent.
  * `:scopes` - nested scopes
    
Assigns are namespaced with `:loc`. They can be accessed in templates as `@loc.{key_name}` (e.g. `@loc.contact`)

> #### Note {: .info}
> 
> - using a `Struct` for `:assign`'s improves the developer experience.
> - when using a `Struct` for assigns it should not be nested in the configuration module; but it can be in the same file as shown in the example.
> - when a `Gettext` module is provided, the assigns must include a value for `:locale`.
>
> During compilation the configuration is validated.


```elixir
# file /lib/example_web/localized_routes.ex
# This example uses a `Struct` for assign, so there is no assign inheritance only struct defaults. When
# using maps, nested scopes will inherit key/values from their parent.

defmodule ExampleWeb.LocalizedRoutes.Assigns do
  @moduledoc false
  defstruct [:contact, locale: "en"]
end

defmodule ExampleWeb.LocalizedRoutes do
  alias Exampleeb.LocalizedRoutes.Assigns

  use PhxLocalizedRoutes,
    scopes: %{
      "/" => %{
        assign: %Assigns{contact: "root@example.com"},
        scopes: %{
          "/europe" => %{
            assign: %Assigns{contact: "europe@example.com"},
            scopes: %{
              "/nl" => %{assigns: %Assigns{locale: "nl", contact: "verkoop@example.nl"}},
              "/be" => %{assigns: %Assigns{locale: "nl", contact: "handel@example.be"}}
            }
          },
        "/gb" => %{assign: %Assigns{contact: "sales@example.com"}
      }
    },
    gettext_module: ExampleWeb.Gettext
end
```

> #### Note {: .info}
>
> Your visitors may prefer another locale than the one set for the route they landed on. Libraries 
> like [Cldr.Plug.SetLocale](https://hexdocs.pm/ex_cldr/Cldr.Plug.SetLocale.html) can detect their preferences.
> You can combine the value set by the route and the value set by a third party library to detect mismatches
> and guide your visitors accordingly.

## Wrapping routes
Wrap the routes within the scope in an `localized` block, providing your created `LocalizedRoutes` module as argument.

```elixir
# file: router.ex
    scope "/", ExampleWeb do
+     localize ExampleWeb.LocalizedRoutes do
        [...routes]
+     end
    end
```

## Extract translatable segments into `routes.po` files

- Run `mix gettext.merge priv/gettext --locale [lang]}` to create a locales' folder
- Run `mix gettext.extract --merge` after you updated routes.

Now, we have created new routes PO file in our structure:

    web_app/priv/gettext
    └─ nl
    | └─ LC_MESSAGES
    | | └─ default.po
    | | └─ errors.po
    | | └─ routes.po    <---- new!
    └─ en
    | └─ LC_MESSAGES
    | | └─ default.po
    | | └─ errors.po
    | | └─ routes.po    <---- new!
    └─ default.pot
    └─ errors.pot
    └─ routes.pot <---- new!

You can translate the route segments in the `.po`-file and recompile the Router module to generate the new multilingual routes.

Finally, Phoenix Localized Routes is able to recompile routes whenever PO files change. To enable this feature, the :gettext compiler needs to be added to the list of Mix compilers.

In mix.exs:

```elixir
def project do
  [
    compilers: [:gettext] ++ Mix.compilers,
  ]
end
```
