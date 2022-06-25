defmodule PhxLocalizedRoutes.Router do
  @moduledoc """
  Provides macro `localize` to generate localized and
  multilingual Phoenix routes with configurable assigns
  which can be used in Controllers and (Live)Views.

  ### Usage
  Instructions how to use this module can be found in the [Usage Guide](USAGE.md).
  """

  alias __MODULE__.Private

  @doc """
  Macro which creates an alternative Router Helpers module
  named `[MyApp].Router.Helpers.Localized` based on the original helper
  module generated by Phoenix (`[MyApp].Router.Helpers`).

  - the new helper module is aliased as `Routes`; making it a drop-in replacement.
  - the original Router Helper module is aliased as `OriginalRoutes`.
  - localised path and URL helpers are generated to support generating localised
  path and URLs. The localized helpers wrap the standard Phoenix helpers.

  **Pseudo code**
        def product_index_path(arg1, arg2) do
          PhxLocalizedRoutes.Helper.loc_route(OriginalRoutes.product_index_path(arg1, arg2), loc_opts)
        end

        def product_index_path(arg1, arg2, arg3) do
          PhxLocalizedRoutes.Helper.loc_route(OriginalRoutes.product_index_path(arg1, arg2, arg3), loc_opts)
        end

        [...]
  """

  defmacro __using__(_options) do
    quote location: :keep do
      @after_compile {PhxLocalizedRoutes.Router.Private, :after_routes_callback}
    end
  end

  @doc """
   Generate localized routes and route helper
   modules.

  This module when `use`d , provides a `localize/1`
  macro that is designed to wrap the standard Phoenix
  route macros such as `get/3`, `put/3` and `live/3`
  in alternate scopes as defined in the config module.

  When a `Gettext` module is defined in the configuration,
  it is used to make route (URL) parts translatable / multilingual.

  Translations for the parts of a given route path are
  translated at compile-time which are then combined into
  a localised route that is added to the standard
  Phoenix routing framework.

  As a result, users can enter URLs using localised
  terms which can enhance user engagement and content
  relevance.

                          =>  pl: produkty  |   edytować
      /products/:id/edit  =>  nl: producten |   bewerken
                          =>  es: producto  |   editar

  Similarly, localised path and URL helpers are
  generated that wrap the standard Phoenix helpers to
  supporting generating localised path and URLs.

  """

  defmacro localize(conf, opts \\ [], do: context) do
    {conf, _} = Code.eval_quoted(conf)
    Private.do_localize(conf, opts, context)
  end
end

defmodule PhxLocalizedRoutes.Router.Private do
  @moduledoc false

  @domain "routes"
  @path_seperator "/"
  @interpolate ":"

  def after_routes_callback(env, _bytecode) do
    original_helper_mod = Module.safe_concat(env.module, :Helpers)
    loc_helper_mod = Module.concat(original_helper_mod, :Localized)

    # credo:disable-for-next-line
    # TODO: refactor for 2.0
    # the shortest helper paths are the original ones which should be wrapped
    shortest_helper_paths =
      env.module
      |> Phoenix.Router.routes()
      |> Enum.group_by(& &1.metadata, & &1.helper)
      |> Enum.reduce([], &[shortest_helper(elem(&1, 1)) | &2])
      |> Enum.uniq()
      |> Enum.map(&"#{&1}_path")

    prelude =
      quote do
        require Logger
        require PhxLocalizedRoutes.Helpers
      end

    functions =
      wrapped_or_delegated_functions(
        original_helper_mod,
        loc_helper_mod,
        shortest_helper_paths
      )

    Module.create(loc_helper_mod, [prelude] ++ functions, Macro.Env.location(env))
    nil
  end

  def do_localize(conf, opts, context) do
    opts = opts |> Enum.into(%{}) |> Map.merge(conf.config())

    [maybe_gettext_triggers(context, opts) | create_phx_scopes(opts.scopes, context, opts)]
  end

  #
  # Inject `dgettext/2` calls with the parts that should be detected by `Gettext`.
  # The parts will be extracted into routes.po files
  #

  def maybe_gettext_triggers(_ctx, %{gettext_module: nil}) do
    []
  end

  def maybe_gettext_triggers(context, %{gettext_module: module} = opts) do
    prelude =
      quote do
        require unquote(module)
      end

    [prelude | gettext_triggers(context, opts)]
  end

  def gettext_triggers({:__block__, _meta, routes}, opts) do
    routes
    |> Stream.flat_map(&gettext_triggers(&1, opts))
    |> Enum.uniq()
  end

  def gettext_triggers({_marker, _meta, [path | _]}, opts) when is_binary(path) do
    path
    |> String.split(@path_seperator, trim: true)
    |> Enum.map(&include_dgettext_call(&1, opts))
  end

  def include_dgettext_call(@interpolate <> _rest, _opts) do
    nil
  end

  def include_dgettext_call(part, opts) do
    quote do
      unquote(opts.gettext_module).dgettext(unquote(@domain), unquote(part))
    end
  end

  def create_phx_scopes(scopes, {marker, meta, _children} = route, opts)
      when marker != :__block__ do
    create_phx_scopes(scopes, {:__block__, meta, [route]}, opts)
  end

  def create_phx_scopes(
        scopes,
        context,
        %{gettext_module: gettext_backend} = _opts
      ) do
    {:__block__, meta, routes} = context

    for {_scope, scope_opts} <- scopes do
      routes =
        case gettext_backend do
          nil -> routes
          _module -> translate_paths(routes, gettext_backend, scope_opts.assign.locale)
        end

      opts =
        Macro.escape(
          path: scope_opts.scope_prefix,
          as: scope_opts.scope_alias,
          private: %{phx_loc_routes: scope_opts},
          assigns: %{loc: scope_opts.assign}
        )

      quoted_scope(opts, meta, routes)
    end
  end

  def quoted_scope(opts, meta, context) do
    quote do
      scope unquote(opts) do
        {:__block__, unquote(meta), unquote(context)}
      end
    end
  end

  defmacro translate_paths_macro(routes, gettext_backend) do
    quote do
      for route <- unquote(routes), do: translate_path(route, unquote(gettext_backend))
    end
  end

  # Gettext requires we set the current process locale
  # in order to translate. This might ordinarily disrupt
  # any user set locale. However since this is only executed
  # at compile time it does not affect runtime behaviour.

  def translate_paths(routes, gettext_backend, locale) do
    Gettext.put_locale(gettext_backend, locale)
    translate_paths_macro(routes, gettext_backend)
  end

  def translate_path({type, meta, [path | rest]}, gettext_backend) when is_binary(path) do
    translated_path =
      path
      |> String.split(@path_seperator)
      |> Enum.map_join(@path_seperator, &translate_part(gettext_backend, &1))

    {type, meta, [translated_path | rest]}
  end

  def translate_part(_backend, part) when part in ["", "*"], do: part
  def translate_part(_backend, @interpolate <> _rest = part), do: part
  def translate_part(gettext_backend, part), do: Gettext.dgettext(gettext_backend, @domain, part)

  def shortest_helper(helpers) do
    helpers
    |> Enum.reject(&is_nil/1)
    |> Enum.min_by(&String.length/1)
  end

  def wrap_function(original_helper_mod, func, args, loc_helper_mod) do
    quote do
      # credo:disable-for-lines:5
      def unquote(func)(unquote_splicing(args)) do
        Logger.debug("Using localized #{unquote(func)} from #{unquote(loc_helper_mod)}")

        PhxLocalizedRoutes.Helpers.loc_route(
          unquote(original_helper_mod).unquote(func)(unquote_splicing(args))
        )
      end
    end
  end

  def delegate_function(original_helper_mod, func, args, _loc_helper_mod) do
    quote do
      defdelegate unquote(func)(unquote_splicing(args)),
        to: unquote(original_helper_mod)
    end
  end

  def wrapped_or_delegated_functions(original_helper_mod, loc_helper_mod, shortest_helper_paths) do
    require Logger

    for {func, arity} <- original_helper_mod.__info__(:functions) do
      args = Macro.generate_arguments(arity, loc_helper_mod)

      if Atom.to_string(func) in shortest_helper_paths do
        Logger.debug("Wrapping #{inspect(func)}/#{arity} from #{inspect(original_helper_mod)}")
        wrap_function(original_helper_mod, func, args, loc_helper_mod)
      else
        delegate_function(original_helper_mod, func, args, loc_helper_mod)
      end
    end
  end
end
