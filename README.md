> [!WARNING]
> This lib is deprecated. It is succeeded by the more powerful and versatile
> Phoenix Router lib [Routex](https://github.com/BartOtten/routex/)

# Phoenix Localized Routes

Localize your Phoenix website with multilingual URLs and custom template assigns;
enhancing user engagement and content relevance.

                        ⇒ /products/:id/edit                  @loc.locale = "en_US"
    /products/:id/edit  ⇒ /nederland/producten/:id/bewerken   @loc.locale = "nl_NL"
                        ⇒ /espana/producto/:id/editar         @loc.locale = "es_ES"


## Top Features and Benefits

- URL format is [customizable](#routes) (no mandatory _website.com/[locale]/page_)
- URLs can [match the language of content](#multilingual-routes); enhancing user
  engagement and content relevance.
- [Less than 10 lines](USAGE.md#helpers) of code to change in existing applications.
- Includes [helper functions](#route-helpers) to generate links to other locales.
- Supports [custom assigns](#custom-assigns) per scope/locale.
- No run-time performance penalty!

Simple when possible, powerful where needed.


## Usage Summary

- Add a configuration file describing which alternate routes to generate.
- Replace **less than 10 lines** of code in your existing `Phoenix` application.
- Optionally:
  - Run [`mix gettext.extract --merge`](`mix gettext.extract`).
  - Translate the URL parts like any other translatable text.
- Run `mix phx.routes` to verify the result.

You can now visit the localized URLs. Links and redirects in your application will
automatically keep the visitors in their current (localized) scope.

## Documentation

[HexDocs](https://hexdocs.pm/phoenix_localized_routes/) (stable)
and [GitHub Pages](https://bartotten.github.io/phoenix_localized_routes/) (development).

We also provide an [example application](#example-application) you can experiment with.

## Requirements and Installation

See the [Usage Guide](USAGE.md) for the requirements and installation instructions.

## Working

A high-level overview of Phoenix Localized Routes' main features.

### Routes

This library provides a localize/1 macro designed to wrap all route macros such as
get/3, put/3 and resources/3. It replicates routes for each `scope` configured in
a `LocalizedRoutes` backend module.

- each configured scope may have nested scopes.
- each configured scope may have custom assigns.
- routes may be translated.
- routes are locale independent (no mandatory `website.com/[locale]/` format)

As a result, you have full control over the format, language and assigns of localized URLs.

### Route Helpers

Phoenix Localized Routes creates locale aware replicas of the standard Phoenix helper
functions to support auto-localized paths and URLs. It places those replicas in a new
module named `[MyAppWeb].Router.Helpers.Localized` along with helpers for each locale
to support linking to a specific locale.

The new module is a drop-in replacement of the standard Phoenix Helper module.
Simply replace the `MyAppWeb.Router.Helpers, as: Routes` alias by
`MyAppWeb.Router.Helpers.Localized, as: Routes` in `myapp_web.ex`.

As a result, all links to localized routes will respect the current scope of a visitor
unless you decide otherwise.


### Multilingual Routes

Phoenix Localized Routes extracts individual parts of a routes' path to a `routes.po` file
for translation. At compile-time it combines the translated parts to create new routes.

As a result, users can enter URLs using localized terms which can enhance user engagement
and content relevance.


### Custom Assigns

Each scope can specify custom assigns. The customs assigns are available in templates
as `@loc` (e.g.`@loc.support_email`).

In order to set the custom assigns for use in views and templates, this lib includes
a `Conn.Plug` module and a LiveView helper module with
[on_mount](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#on_mount/1) callback.
The modules create a bridge to share assigns between Phoenix Views and Phoenix Live Views.

As a result, using different assigns per locale is a matter of plug-and-play.


## Example Application

An example Phoenix app using translated routes and custom assigns is available at GitHub.

``` bash
  git clone https://github.com/BartOtten/phoenix_localized_routes_example.git
  cd phoenix_localized_routes_example
  iex -S mix phx.server
```

Once the application is running, have a look at the
[example page](http://localhost:4000/europe/nl/producten/).
