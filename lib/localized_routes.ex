defmodule PhxLocalizedRoutes do
  @moduledoc """
  Macro to create and validate `PhxLocalizedRoutes` configuration modules with
  convenience callbacks to fetch specific values. For maximum performance, most
  callbacks return precompiled values with precomputed additional data.

  When used with an app depending on `Phoenix.LiveView` it also creates a LiveHelper module.

  For information how to use this lib see the [Usage Guide](USAGE.md)
  """

  alias __MODULE__.Private

  @type opts :: [
          scopes: opts_scopes,
          gettext_module: module
        ]
  @type opts_scopes :: %{binary => opts_scope_map}
  @type opts_scope_map :: %{
          optional(:assign) => %{atom => any},
          optional(:scopes) => opts_scopes
        }

  # type aliases
  @type config :: PhxLocalizedRoutes.Config.t()
  @type scopes_nested :: PhxLocalizedRoutes.Scope.Nested.kv_map()
  @type scope_nested :: PhxLocalizedRoutes.Scope.Nested.t()
  @type scopes :: PhxLocalizedRoutes.Scope.Flat.kv_map()
  @type scope :: PhxLocalizedRoutes.Scope.Flat.t()

  # define callbacks
  @doc "Returns the scopes in a flat structure"
  @callback scopes :: scopes

  @doc "Returns the scopes in a nested structure"
  @callback scopes_nested :: scopes_nested

  @doc "Returns the scope of given scope helper"
  @callback get_scope(scope_helper :: nil | String.t()) :: scope

  @doc """
  Return a list of unique values assigned to given key. Returns a list of tuples
  with unique combinations when a list of keys is given.

  **Example**
      iex> ExampleWeb.LocalizedRoutes.assigned_values(:locale)
      ["en", "nl"]

      iex> ExampleWeb.LocalizedRoutes.assigned_values([:locale, :locale])
      [{"en", "en-GB"}, {"nl", "nl-NL"}, {"nl", "nl_BE"}]
  """
  @callback assigned_values(key_or_keys :: atom | String.t() | list) :: list

  @doc "Returns the configuration with precomputed values and flattened scopes"
  @callback config :: config

  @spec __using__(opts :: Macro.t()) :: Macro.output()
  defmacro __using__(opts) do
    {opts, _} = Code.eval_quoted(opts, [], __CALLER__)
    Private.compile_actions(opts, __CALLER__, __ENV__)
  end
end

defmodule PhxLocalizedRoutes.Private do
  @moduledoc false

  alias PhxLocalizedRoutes, as: PLR
  alias PLR.Config
  alias PLR.Exceptions
  alias PLR.Scope

  require Logger

  # type aliases
  @type caller :: Macro.Env.t()
  @type env :: Macro.Env.t()
  @type opts :: PLR.opts()
  @type opts_scopes :: PLR.opts_scopes()
  @type opts_scope_map :: PLR.opts_scope_map()
  @type scopes_nested :: PLR.Scope.Nested.kv_map()
  @type scopes_nested_tuple :: PLR.Scope.Nested.kv_tuple()
  @type scope_nested :: PLR.Scope.Nested.t()
  @type scopes :: PLR.Scope.Flat.kv_map()
  @type scope_tuple :: PLR.Scope.Flat.kv_tuple()
  @type scope :: PLR.Scope.Flat.t()
  @type config :: PLR.Config.t()

  @spec compile_actions(opts, caller, env) :: Macro.output()
  def compile_actions(opts, caller, env) do
    print_compile_header(caller.module, in_compilers?(:gettext), opts)

    if in_deps?(:phoenix_live_view),
      do: create_live_helper_module(caller.module, env)

    opts
    |> prepare_build_args()
    |> build_ast()
  end

  @spec prepare_build_args(opts) :: %{
          opts: Macro.t(),
          scopes_nested: Macro.t(),
          config: Macro.t()
        }
  def prepare_build_args(opts) do
    scopes_nested = add_precomputed_values!(opts[:scopes])
    config = build_config([{:scopes_nested, scopes_nested} | opts])

    :ok = validate_config!(config)

    safe_opts = Macro.escape(opts)
    safe_scopes_nested = Macro.escape(scopes_nested)
    safe_config = Macro.escape(config)

    %{opts: safe_opts, scopes_nested: safe_scopes_nested, config: safe_config}
  end

  # credo:disable-for-lines:25
  @spec build_ast(map) :: Macro.output()
  def build_ast(args) do
    quote location: :keep,
          bind_quoted: [opts: args.opts, scopes_nested: args.scopes_nested, config: args.config] do
      @behaviour PhxLocalizedRoutes

      # set attributes
      @scopes_nested scopes_nested
      @scopes_flat config.scopes
      @gettext config.gettext_module
      @config config

      # define accessors
      def scopes_nested, do: @scopes_nested
      def scopes, do: @scopes_flat
      def config, do: @config

      # define functions
      def get_scope(scope_helper), do: Map.get(@scopes_flat, scope_helper)

      def assigned_values(key_or_keys),
        do: PhxLocalizedRoutes.Private.assigned_values(@scopes_flat, key_or_keys)
    end
  end

  @spec build_config(keyword) :: config()
  def build_config(opts) do
    scopes_flat = opts |> Keyword.get(:scopes_nested) |> flatten_scopes()
    gettext = Keyword.get(opts, :gettext_module)

    struct(Config, %{scopes: scopes_flat, gettext_module: gettext})
  end

  # return a list of unique values assigned to given key. Returns a list
  # of tuples with unique combinations when a list of keys is given.
  @spec assigned_values(scopes, atom | binary) :: list(any)
  def assigned_values(scopes, key) when is_atom(key) or is_binary(key),
    do: scopes |> assigned_values([key]) |> Stream.map(&elem(&1, 0)) |> Enum.uniq()

  @spec assigned_values(scopes, list(atom | binary)) :: list({atom | binary, any})
  def assigned_values(scopes, keys) when is_list(keys) do
    scopes |> aggregate_assigns(keys) |> Enum.uniq()
  end

  # takes a nested map of maps and returns a flat map with concatenated keys, aliases and prefixes.
  @spec flatten_scopes(scopes :: scopes_nested) :: scopes()
  def flatten_scopes(scopes), do: scopes |> do_flatten_scopes() |> List.flatten() |> Map.new()

  @spec do_flatten_scopes(scopes_nested, nil | {binary, any} | {nil, nil}) ::
          list(scopes)
  def do_flatten_scopes(scopes, parent \\ {nil, nil}) do
    Enum.reduce(scopes, [], fn
      {_, scope_opts} = full_scope, acc ->
        new_scope = flatten_scope(full_scope, parent)
        flattened_subtree = do_flatten_scopes(scope_opts.scopes, new_scope)

        [[new_scope | flattened_subtree] | acc]
    end)
  end

  @spec flatten_scope(scopes_nested_tuple(), scope_tuple) :: scope_tuple
  def flatten_scope({_scope, scope_opts}, {_p_scope, p_scope_opts})
      when is_nil(p_scope_opts) or is_nil(p_scope_opts.scope_alias) do
    scope_opts = Map.drop(scope_opts, [:scopes])
    scope_key = scope_opts.assign.scope_helper
    {scope_key, struct(Scope.Flat, Map.from_struct(scope_opts))}
  end

  def flatten_scope({_scope, scope_opts}, {_p_scope, p_scope_opts}) do
    flattened_scope_prefix = Path.join(p_scope_opts.scope_prefix, scope_opts.scope_prefix)

    flattened_scope_alias =
      String.to_atom(
        "#{Atom.to_string(p_scope_opts.scope_alias)}_#{Atom.to_string(scope_opts.scope_alias)}"
      )

    scope_opts = %{
      scope_opts
      | scope_prefix: flattened_scope_prefix,
        scope_alias: flattened_scope_alias
    }

    new_scope_opts = Map.drop(scope_opts, [:scopes])
    new_scope_key = scope_opts.assign.scope_helper

    {new_scope_key, struct(Scope.Flat, Map.from_struct(new_scope_opts))}
  end

  @spec get_slug_key(binary) :: binary
  def get_slug_key(slug), do: slug |> String.replace("/", "_") |> String.replace_prefix("_", "")

  @spec get_scope_meta(slug :: binary, list(binary)) :: %{
          key: nil | binary,
          path: list,
          prefix: binary,
          alias: nil | atom,
          helper: nil | binary
        }
  def get_scope_meta("/", []) do
    %{key: nil, path: [], prefix: "", alias: nil, helper: nil}
  end

  def get_scope_meta(slug, p_scope_path) when is_list(p_scope_path) do
    key = get_slug_key(slug)
    path = Enum.concat(p_scope_path, [key])

    %{
      key: key,
      path: path,
      prefix: key,
      alias: String.to_atom(key),
      helper: Enum.join(path, "_")
    }
  end

  @spec add_precomputed_values!(opts_scopes, parent_scope :: scope_nested) :: scopes_nested
  def add_precomputed_values!(scopes, p_scope \\ %Scope.Nested{}) do
    for {slug, scope} <- scopes, into: %{} do
      scope = Map.put_new(scope, :assign, Map.new())
      scope_meta = get_scope_meta(slug, p_scope.scope_path)
      assign_map = destruct(scope.assign)

      new_assign =
        p_scope.assign
        |> Map.merge(assign_map)
        |> Map.put(:scope_helper, scope_meta.helper)

      new_opts =
        maybe_compute_nested_scopes(
          %Scope.Nested{
            assign: new_assign,
            scope_path: scope_meta.path,
            scope_prefix: Path.join("/", scope_meta.prefix),
            scope_alias: scope_meta.alias
          },
          scope
        )

      {scope_meta.key, new_opts}
    end
  end

  @spec destruct(map | struct) :: map
  def destruct(map_or_struct) when is_struct(map_or_struct), do: Map.from_struct(map_or_struct)
  def destruct(map_or_struct) when is_map(map_or_struct), do: map_or_struct

  @spec maybe_compute_nested_scopes(scope_nested, opts_scope_map) :: scope_nested
  def maybe_compute_nested_scopes(
        %Scope.Nested{} = scope_struct,
        %{scopes: scopes} = _scope_map
      ),
      do: Map.put(scope_struct, :scopes, add_precomputed_values!(scopes, scope_struct))

  def maybe_compute_nested_scopes(%Scope.Nested{} = scope_struct, %{} = _scope_map),
    do: scope_struct

  @spec aggregate_assigns(scopes, list(binary | atom), list) :: list
  def aggregate_assigns(scopes, keys, acc \\ []) do
    scopes
    |> Enum.reduce(acc, fn
      {_slug, %{assign: assign}}, acc ->
        [get_values(assign, keys) | acc]
    end)
    |> List.flatten()
    |> Enum.uniq()
  end

  @spec validate_config!(config) :: :ok
  def validate_config!(%Config{} = opts) do
    ^opts =
      opts
      |> validate_root_slug!()
      |> validate_matching_assign_keys!()
      |> validate_lang_keys!()

    :ok
  end

  # checks whether the scopes has a top level "/" (root) slug
  @spec validate_root_slug!(config) :: config
  def validate_root_slug!(%Config{scopes: scopes} = opts) do
    unless Enum.any?(scopes, fn {_scope, scope_opts} -> scope_opts.scope_prefix == "/" end),
      do: raise(Exceptions.MissingRootSlugError)

    opts
  end

  # assign keys should match in order to have uniform availability
  @spec validate_matching_assign_keys!(config) :: config
  def validate_matching_assign_keys!(%Config{scopes: %{nil: reference_scope} = scopes} = opts) do
    reference_keys = get_sorted_assigns_keys(reference_scope)

    Enum.each(scopes, fn
      {nil, ^reference_scope} = _reference_scope ->
        :noop

      scope ->
        ^scope = validate_matching_assign_keys!(scope, reference_keys)
    end)

    opts
  end

  @spec validate_matching_assign_keys!(scope_tuple, list(atom | binary)) :: scope_tuple
  def validate_matching_assign_keys!({key, scope_opts} = scope, reference_keys) do
    assigns_keys = get_sorted_assigns_keys(scope_opts)

    if assigns_keys != reference_keys,
      do:
        raise(Exceptions.AssignsMismatchError,
          scope: key,
          expected_keys: reference_keys,
          actual_keys: assigns_keys
        )

    scope
  end

  @spec validate_lang_keys!(config) :: config
  # when gettext_module is set, assigns should include the :locale key
  def validate_lang_keys!(%Config{gettext_module: nil} = opts), do: opts

  def validate_lang_keys!(%Config{gettext_module: mod, scopes: scopes} = opts) do
    scope = get_first_scope(scopes)

    unless is_atom(mod) && is_binary(Map.get(scope.assign, :locale)),
      do: raise(Exceptions.MissingLocaleAssignError)

    opts
  end

  @spec create_live_helper_module(caller_module :: module, env :: Macro.Env.t()) ::
          {:module, module(), binary(), term()}
  def create_live_helper_module(caller_module, env) do
    # Create a mount module and pass the calling (config) module as the mount identifier

    # credo:disable-for-next-line
    mount_module = Module.concat([caller_module, :LiveHelpers])

    contents =
      quote do
        def on_mount(:default, params, session, socket) do
          PhxLocalizedRoutes.LiveHelpers.on_mount(
            unquote(caller_module),
            params,
            session,
            socket
          )
        end
      end

    Module.create(mount_module, contents, Macro.Env.location(env))
  end

  @spec in_compilers?(app :: atom) :: boolean
  def in_compilers?(app) do
    Mix.Project.get!().project()
    |> Access.get(:compilers)
    |> Enum.member?(app)
  end

  @spec in_deps?(app :: atom) :: boolean
  def in_deps?(app) do
    Mix.Project.get!().project()
    |> Access.get(:deps)
    |> Enum.map(&elem(&1, 0))
    |> Enum.member?(app)
  end

  @spec print_compile_header(
          caller_module :: module,
          gettext_in_compilers? :: boolean,
          opts :: opts
        ) :: :ok
  def print_compile_header(caller_module, gettext_in_compilers?, config_mod) do
    unless is_nil(config_mod[:gettext_module]) or gettext_in_compilers? do
      router_module =
        caller_module
        |> Module.split()
        |> List.first()
        |> Kernel.<>(".Router")

      Logger.warn(
        "When route translations are updated, run `mix compile --force #{router_module}`"
      )
    end

    :ok
  end

  @spec get_values(map, list(binary | atom)) :: tuple
  defp get_values(assign, keys),
    do: List.to_tuple(for(key <- keys, do: Map.get(assign, key)))

  @spec get_first_scope(scopes) :: scope
  defp get_first_scope(scopes), do: scopes |> Map.to_list() |> hd() |> elem(1)

  @spec get_sorted_assigns_keys(map) :: list()
  defp get_sorted_assigns_keys(%{assign: assign}) when is_map(assign),
    do: assign |> Map.keys() |> Enum.sort()

  defp get_sorted_assigns_keys(_scope_opts), do: []
end
