![Coveralls](https://img.shields.io/coveralls/github/BartOtten/phoenix_localized_routes)
[![Build Status](https://github.com/BartOtten/phoenix_localized_routes/actions/workflows/elixir.yml/badge.svg?event=push)](https://github.com/BartOtten/phoenix_localized_routes/actions/workflows/elixir.yml)
[![Last Updated](https://img.shields.io/github/last-commit/BartOtten/phoenix_localized_routes.svg)](https://github.com/BartOtten/phoenix_localized_routes/commits/main)
[![Hex.pm](https://img.shields.io/hexpm/v/phoenix_localized_routes)](https://hex.pm/packages/phoenix_localized_routes)
![Hex.pm](https://img.shields.io/hexpm/l/phoenix_localized_routes)


# Phoenix Localized Routes

Localize your Phoenix website with multilingual URL's and custom template assigns; enhancing 
user engagement and content relevance.
                            
                        =>  /products/:id/edit                 @loc.locale = "en_US"
    /products/:id/edit  =>  /nederland/producten/:id/bewerken  @loc.locale = "nl_NL"
                        =>  /espana/producto/:id/editar        @loc.locale = "es_ES"


## Features and Benefits

- [x]  URL format is [locale independent](#routes) (no mandatory `website.com/[locale]/page`)
- [x]  URL [matches language of content](#multilingual-routes); enhancing user engagement and content relevance.
- [x]  [Less than 10 lines](USAGE.md#helpers) of code to be changed in existing code Phoenix applications.
- [x]  Includes [helper functions](#route-helpers) to generate links to other locales.
- [x]  Supports [custom assigns](#custom-assigns) per scope/locale.
- [x]  Routes and helpers generated at compile time; no performance penalty!

Simple when possible, powerful where needed.


## Usage Summary

- Add a configuration file describing which alternate routes to generate.
- Replace **less than 10 lines** of code in your existing `Phoenix` application.
- Optionally:
  - Run `mix gettext.extract --merge`.
  - Translate the URL parts like any other translatable text.
- Run `mix phx.routes` to verify the result.

All links in your application will now automatically keep the user in the correct scope.

## Documentation

Documentation uuis located at [HexDocs](https://hexdocs.pm/phoenix_localized_routes/) (published) and [GitHub Pages](https://bartotten.github.io/phoenix_localized_routes/) (development). We also provide an [example application](#example-application)

## Requirements and  Installation

See the [Usage Guide](USAGE.md) for the requirements and installation instructions.

## Working

This chapter aims at providing a high over view of the main features of Phoenix Localized Routes.

### Routes

This library provides a localize/1 macro designed to wrap all route macros such as get/3, put/3 and resources/3. It replicates routes for each `scope` configured in a `LocalizedRoutes` backend module.

- each configured scope may have nested scopes.
- each configured scope may have custom assigns.
- routes may be translated.
- routes are locale independent (no mandatory `website.com/[locale]/` format)

As a result, you have full control over the format, language and assigns of localized URL's.

### Route Helpers

Phoenix Localized Routes creates locale aware replicas of the standard Phoenix helper functions to support auto-localized paths and URLs. It places those replicas in a new module named `[MyAppWeb].Router.Helpers.Localized` along with helpers for each locale to support linking to a specific locale.

The new module is a drop-in replacement of the standard Phoenix Helper module, so you can replace the `MyAppWeb.Router.Helpers, as: Routes` alias by `MyAppWeb.Router.Helpers.Localized, as: Routes` in `myapp_web.ex`. 

As a result, all links to localized routes will respect the current scope of a visitor unless you decide otherwise.


### Multilingual Routes

Phoenix Localized Routes extracts each individual part of a route path to a `routes.po` file for translation. During compile-time it combines the translated parts to create translated routes. 

As a result, users can enter URLs using localized terms which can enhance user engagement and content relevance.


### Custom Assigns

Each scope can specify custom assigns. The customs assigns are available in templates as `@loc` (e.g.`@loc.support_email`).

In order to set the custom assigns for use in views and templates, this lib includes a `Conn.Plug` and a helper module with [on_mount](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#on_mount/1) callback. There modules function as bridge between Phoenix Views and Phoenix Live Views.

As a result, using different assigns per locale is a matter of plug-and-play.


## Example Application
An example Phoenix application showing translated routes and custom assigns is available at GitHub.

``` bash
  git clone https://github.com/BartOtten/phoenix_localized_routes_example.git
  cd phoenix_localized_routes_example
  iex -S mix phx.server
```

Once the application is running, have a look at the [example page](http://localhost:4000/europe/nl/producten/).


