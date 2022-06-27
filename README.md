![Coveralls](https://img.shields.io/coveralls/github/BartOtten/phoenix_localized_routes)
[![Build Status](https://github.com/BartOtten/phoenix_localized_routes/actions/workflows/elixir.yml/badge.svg?event=push)](https://github.com/BartOtten/phoenix_localized_routes/actions/workflows/elixir.yml)
[![Last Updated](https://img.shields.io/github/last-commit/BartOtten/phoenix_localized_routes.svg)](https://github.com/BartOtten/phoenix_localized_routes/commits/main)

# Phoenix Localized Routes
Localize your Phoenix website with multilingual URL's and custom template assigns; enhancing 
user engagement and content relevance.
                            
                        =>  /products/:id/edit          @loc.contact = "int@company.com"
    /products/:id/edit  =>  /nl/producten/:id/bewerken  @loc.contact = "netherlands@company.com"
                        =>  /es/producto/:id/editar     @loc.contact = "spain@company.com"

## Features and Benefits
- [x]  URL matches language of content which can enhance user engagement and content
  relevance.
- [x]  Works with Phoenix View and Phoenix LiveView
- [x]  Unlimited nesting
- [x]  Supports dynamic nesting (eg. `/{continent}/{county}/{page}` *and* `/{country}/{page}`)
- [x]  Less boilerplate in your `routes.ex`
- [x]  Generates routes at compile time; no performance penalty!
- [x]  Easily add custom assigns to your (localized) routes
- [x]  Easily generate links to matching pages in other locales
- [x]  Can be used for non-locale alternate routing (eg. `/{sport}/{activity}`)

## Documentation
Documentation can be found at [HexDocs](https://hexdocs.pm/phoenix_localized_routes/) (published) and [GitHub Pages](https://bartotten.github.io/phoenix_localized_routes/) (development)

## Usage Summary
- Add a few line of code to your `Phoenix` application.
- Add a configuration file describing which alternate routes to generate.
- Optionally:
  - Run `mix gettext.extract --merge`.
  - Translate the URL parts like any other translatable text.
- Run `mix phx.routes` to verify the result.

All links in your application will now automatically keep the user in the correct scope.

The full guide is written in the [Usage Guide](USAGE.md).

## Requirements
- Elixir >=1.11
- Phoenix >= 1.6.0
- Phoenix LiveView >= 0.16 (optional)

## Example
An example Phoenix application showing the (nested) routes and custom assigns.

    git clone https://github.com/BartOtten/phoenix_localized_routes_example.git
    cd phoenix_localized_routes_example
    iex -S mix phx.server

    http://localhost:4000/
    http://localhost:4000/europe

    http://localhost:4000/products
    http://localhost:4000/europe/nl/producten/

## Installation

You can install this library by adding it to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_localized_routes, "~> 0.1.0"}
  ]
end
```

To configure your routes have a look at the [Usage Guide](USAGE.md).

## Technical Notes

Phoenix Localized Routes makes use of `Macro`'s to wrap Phoenix Router and Phoenix Router Helpers. It generates alternate helpers and paths based on the routes defined in `[YourApp].Routes`. Alternate routes are generated at compile time; making them just as fast as the explicitly defined routes.

If a wrapped function call fails, the original function will be called to ensure your application always links to an available page.

To set the custom assigns for use in templates, a `Conn.Plug` and a helper module with  [on_mount](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#on_mount/1) callback are included.


