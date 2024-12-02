# Changelog
## 0.1.3-rc.0
### Support Phoenix Verified Routes
Phoenix 1.7 includes a new Phoenix.VerifiedRoutes feature which
provides ~p for route generation with compile-time verification.

This release adds support for Localized Verified Routes using
sigil ~l. The sigil used can be customized by setting the `sigil_localized`
option in the configuration.

#### Overriding sigil ~p
The default sigil ~p used by Phoenix.VerifiedRoutes can be
overridden by setting `sigil_localized: "~p"`. When doing so, the original
sigil is by default renamed to ~o. This can be customized by setting
the `sigil_original` option.

**Example**
```elixir
    sigil_localized: "~p",
    sigil_original: "~q"
```

For an example of how to implement Phoenix Localized Routes using the
new Verified Routes, have a look [at the commits](https://github.com/BartOtten/phoenix_localized_routes_example/compare/bo/phx1.7?expand=1) of the example app (branch bo/1.7).

### Other changes
* Use Phoenix.Component.assign for Phoenix >= 1.7

## 0.1.2
### 1.Bugfixes
* Support Elixir >= 1.14

## 0.1.1

### 1. Enhancements
* Added typespecs
* Modules split for better test experience

### 2.Bugfixes
* Fix errors reported by Dialyzer

### 3. Breaking Changes
* `Helpers.loc_route` requires :loc_opts of type `Scope.Flat.t() | nil`

## 0.1.0

Initial release
