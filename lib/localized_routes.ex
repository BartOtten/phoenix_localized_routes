defmodule PhxLocalizedRoutes.Scope.Nested do
  @moduledoc """
  Struct for scopes with nested scopes
  """
  @type t :: %__MODULE__{
          assign: %{atom => any} | nil,
          scopes: PhxLocalizedRoutes.scopes() | nil,
          scope_path: list(binary),
          scope_prefix: binary,
          scope_alias: atom
        }

  defstruct [
    :scope_alias,
    scopes: %{},
    assign: %{},
    scope_path: [],
    scope_prefix: ""
  ]
end

defmodule PhxLocalizedRoutes.Scope.Flat do
  @moduledoc """
  Struct for flattened scopes
  """
  @type t :: %__MODULE__{
          assign: %{atom => any} | nil,
          scope_path: list(binary),
          scope_prefix: binary,
          scope_alias: atom
        }

  defstruct [
    :scope_alias,
    scope_prefix: "",
    scope_path: [],
    assign: %{}
  ]
end

defmodule PhxLocalizedRoutes.Config do
  @moduledoc """
  Struct for compiled configuration
  """
  @type scopes :: %{(binary | nil) => PhxLocalizedRoutes.Scope.Flat.t()}
  @type gettext :: module | nil
  @type t :: %__MODULE__{
          scopes: scopes,
          gettext_module: gettext
        }

  @enforce_keys [:scopes]
  defstruct [:scopes, :gettext_module]
end

defmodule PhxLocalizedRoutes do
  @moduledoc """
  Macro to create and validate `PhxLocalizedRoutes` configuration module with
  convenience callbacks to fetch specific values. It also creates a LiveHelper
  module to be used in LiveView projects.  For maximum performance, most functions
  return values including additional data computed at compile time.
  """

  alias __MODULE__.Private

  @typedoc """
      Type that represents a config module map containing scope key/values.
  """
  @type scope_map :: %{
          assign: %{atom => any} | nil,
          scopes: scopes_map | nil
        }
  @type scopes_map :: %{binary => scope_map}
  @type scopes_nested :: %{binary => PhxLocalizedRoutes.Scope.Nested.t()}
  @type scopes :: PhxLocalizedRoutes.Config.scopes()
  @type opts :: [
          scopes: scopes_map,
          gettext_module: module
        ]

  # define callbacks
  @doc "Return the scopes in a flat structure"
  @callback scopes :: scopes

  @doc "Return the scopes in a nested structure"
  @callback scopes_nested :: scopes_nested

  @doc "Return the configuration of given scope helper"
  @callback get_scope(scope_helper :: nil | String.t()) :: PhxLocalizedRoutes.Scope.Flat.t()

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
  @callback config :: map

  @spec __using__(opts) :: Macro.t()
  defmacro __using__(opts) do
    Private.print_compile_header(__CALLER__, Private.in_compilers?(:gettext), opts)

    if Private.in_deps?(:phoenix_live_view),
      do: Private.create_live_helper_module(__CALLER__, __ENV__)

    quote location: :keep, bind_quoted: [opts: opts, module: __MODULE__] do
      @behaviour module

      scopes_nested = Private.add_precomputed_values!(opts[:scopes])
      config_module = Module.safe_concat(module, Config)
      config = Private.build_config(config_module, [{:scopes_nested, scopes_nested} | opts])

      Private.validate_config!(config)

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
      def assigned_values(key_or_keys), do: Private.assigned_values(@scopes_flat, key_or_keys)
    end
  end
end

defmodule PhxLocalizedRoutes.Private do
  @moduledoc false

  alias PhxLocalizedRoutes, as: PLR
  require Logger

  @spec build_config(module, keyword) :: PLR.Config.t()
  def build_config(module, opts) do
    scopes_flat = opts |> Keyword.get(:scopes_nested) |> flatten_scopes()
    gettext = Keyword.get(opts, :gettext_module)

    struct(module, %{scopes: scopes_flat, gettext_module: gettext})
  end

  # return a list of unique values assigned to given key. Returns a list
  # of tuples with unique combinations when a list of keys is given.
  @spec assigned_values(scopes :: PLR.scopes(), atom | binary) :: list(any)
  def assigned_values(scopes, key) when is_atom(key) or is_binary(key),
    do: scopes |> assigned_values([key]) |> Stream.map(&elem(&1, 0)) |> Enum.uniq()

  @spec assigned_values(scopes :: PLR.scopes(), list(atom | binary)) :: list({atom | binary, any})
  def assigned_values(scopes, keys) when is_list(keys) do
    scopes |> aggregate_assigns(keys) |> Enum.uniq()
  end

  # takes a nested map of maps and returns a flat map with concatenated keys, aliases and prefixes.
  @spec flatten_scopes(scopes :: PLR.scopes_nested()) :: PLR.scopes()
  def flatten_scopes(scopes), do: scopes |> do_flatten_scopes() |> List.flatten() |> Map.new()

  @spec do_flatten_scopes(PLR.scopes_nested(), nil | {binary, any} | {nil, nil}) ::
          list(PLR.scopes())
  def do_flatten_scopes(scopes, parent \\ {nil, nil}) do
    Enum.reduce(scopes, [], fn
      {_, scope_opts} = full_scope, acc ->
        new_scope = flatten_scope(full_scope, parent)
        flattened_subtree = do_flatten_scopes(scope_opts.scopes, new_scope)

        [[new_scope | flattened_subtree] | acc]
    end)
  end

  @spec flatten_scope({binary, PLR.Scope.Nested.t()}, {binary | nil, PLR.Scope.Flat.t() | nil}) ::
          {binary, PLR.Scope.Flat.t()}
  def flatten_scope({_scope, scope_opts}, {_p_scope, p_scope_opts})
      when is_nil(p_scope_opts) or is_nil(p_scope_opts.scope_alias) do
    scope_opts = Map.drop(scope_opts, [:scopes])
    scope_key = scope_opts.assign.scope_helper
    {scope_key, struct(PLR.Scope.Flat, Map.from_struct(scope_opts))}
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

    {new_scope_key, struct(PLR.Scope.Flat, Map.from_struct(new_scope_opts))}
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

  @spec add_precomputed_values!(PLR.scopes_map(), PLR.Scope.Nested.t()) :: PLR.scopes_nested()
  def add_precomputed_values!(scopes, p_scope \\ %PLR.Scope.Nested{}) do
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
          %PLR.Scope.Nested{
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

  @spec maybe_compute_nested_scopes(PLR.Scope.Nested.t(), PLR.scope_map()) :: PLR.Scope.Nested.t()
  def maybe_compute_nested_scopes(
        %PLR.Scope.Nested{} = scope_struct,
        %{scopes: scopes} = _scope_map
      ),
      do: Map.put(scope_struct, :scopes, add_precomputed_values!(scopes, scope_struct))

  def maybe_compute_nested_scopes(%PLR.Scope.Nested{} = scope_struct, %{} = _scope_map),
    do: scope_struct

  @spec aggregate_assigns(PLR.scopes(), list(binary | atom), list) :: list
  def aggregate_assigns(scopes, keys, acc \\ []) do
    scopes
    |> Enum.reduce(acc, fn
      {_slug, %{assign: assign}}, acc ->
        [get_values(assign, keys) | acc]
    end)
    |> List.flatten()
    |> Enum.uniq()
  end

  @spec validate_config!(PLR.Config.t()) :: :ok
  def validate_config!(opts) do
    ^opts =
      opts
      |> validate_root_slug!()
      |> validate_matching_assign_keys!()
      |> validate_lang_keys!()

    :ok
  end

  # checks whether the scopes has a top level "/" (root) slug
  @spec validate_root_slug!(PLR.Config.t()) :: PLR.Config.t()
  def validate_root_slug!(%{scopes: scopes} = opts) do
    unless Enum.any?(scopes, fn {_scope, scope_opts} -> scope_opts.scope_prefix == "/" end),
      do: raise(PLR.Exceptions.MissingRootSlugError)

    opts
  end

  # assign keys should match in order to have uniform availability
  @spec validate_matching_assign_keys!(PLR.Config.t()) :: PLR.Config.t()
  def validate_matching_assign_keys!(%PLR.Config{scopes: %{nil: reference_scope} = scopes} = opts) do
    reference_keys = get_sorted_assigns_keys(reference_scope)

    Enum.each(scopes, fn
      {nil, ^reference_scope} = _reference_scope ->
        :noop

      scope ->
        ^scope = validate_matching_assign_keys!(scope, reference_keys)
    end)

    opts
  end

  @spec validate_matching_assign_keys!({binary, PLR.Scope.Flat.t()}, list(atom | binary)) ::
          {binary, PLR.Scope.Flat.t()}
  def validate_matching_assign_keys!({key, scope_opts} = scope, reference_keys) do
    assigns_keys = get_sorted_assigns_keys(scope_opts)

    if assigns_keys != reference_keys,
      do:
        raise(PLR.Exceptions.AssignsMismatchError,
          scope: key,
          expected_keys: reference_keys,
          actual_keys: assigns_keys
        )

    scope
  end

  @spec validate_lang_keys!(PLR.Config.t()) :: PLR.Config.t()
  # when gettext_module is set, assigns should include the :locale key
  def validate_lang_keys!(opts) when not is_map_key(opts, :gettext_module), do: opts
  def validate_lang_keys!(%{gettext_module: nil} = opts), do: opts

  def validate_lang_keys!(%{gettext_module: mod, scopes: scopes} = opts) do
    scope = get_first_scope(scopes)

    unless is_atom(mod) && is_binary(Map.get(scope.assign, :locale)),
      do: raise(PLR.Exceptions.MissingLocaleAssignError)

    opts
  end

  @spec create_live_helper_module(caller :: Macro.Env.t(), env :: Macro.Env.t()) ::
          {:module, module(), binary(), term()}
  def create_live_helper_module(caller, env) do
    # Create a mount module and pass the calling (config) module as the mount identifier

    # credo:disable-for-next-line
    mount_module = Module.concat([caller.module, :LiveHelpers])

    contents =
      quote do
        def on_mount(:default, params, session, socket) do
          PLR.LiveHelpers.on_mount(
            unquote(caller.module),
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
          caller :: Macro.Env.t(),
          gettext_in_compilers? :: boolean,
          opts :: PLR.opts()
        ) :: :ok
  def print_compile_header(caller, gettext_in_compilers?, config_mod) do
    unless is_nil(config_mod[:gettext_module]) or gettext_in_compilers? do
      router_module =
        caller.module
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

  defp get_first_scope(scopes), do: scopes |> Map.to_list() |> hd() |> elem(1)

  defp get_sorted_assigns_keys(%{assign: assign}) when is_map(assign),
    do: assign |> Map.keys() |> Enum.sort()

  defp get_sorted_assigns_keys(_scope_opts), do: []
end
