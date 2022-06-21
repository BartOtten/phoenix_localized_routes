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
  @type scopes :: %{binary => PhxLocalizedRoutes.Scope.Flat.t()}
  @type gettext :: module | nil
  @type t :: %__MODULE__{
          scopes: scopes,
          gettext_module: gettext
        }

  @enforce_keys [:scopes, :gettext_module]
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
  @callback scopes :: map

  @doc "Return the scopes in a nested structure"
  @callback scopes_nested :: map

  @doc "Return the configuration of given scope helper"
  @callback get_scope(scope_helper :: nil | String.t()) :: map

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
    Private.print_compile_header(__CALLER__, Private.gettext_in_compilers?(), opts)
    Private.create_live_helper_module(__CALLER__, __ENV__)

    quote location: :keep, bind_quoted: [opts: opts, module: __MODULE__] do
      @behaviour module

      {scopes_nested, scopes_flat, gettext} = Private.get_attr_values(opts)

      # set attributes
      @scopes_nested scopes_nested
      @scopes_flat scopes_flat
      @gettext gettext
      @config opts
              |> Enum.into(%{})
              |> Map.merge(%{scopes: @scopes_flat, gettext_module: @gettext})
              |> then(&struct(Module.safe_concat(module, Config), &1))

      Private.validate_config!(@config)

      # define accessors
      def scopes_nested, do: @scopes_nested

      def scopes, do: @scopes_flat

      def config, do: @config

      # define functions
      def get_scope(scope_helper) do
        Map.get(@scopes_flat, scope_helper)
      end

      def assigned_values(key_or_keys),
        do: Private.assigned_values(@scopes_flat, key_or_keys)
    end
  end
end

defmodule PhxLocalizedRoutes.Private do
  @moduledoc false

  alias PhxLocalizedRoutes, as: PLR
  alias PhxLocalizedRoutes.Exceptions.AssignsMismatchError
  alias PhxLocalizedRoutes.Exceptions.MissingLocaleAssignError
  alias PhxLocalizedRoutes.Exceptions.MissingRootSlugError
  alias PhxLocalizedRoutes.LiveHelpers
  require Logger

  @spec get_attr_values(PhxLocalizedRoutes.opts()) ::
          {PLR.scopes_nested(), PLR.scopes(), gettext_module :: module | nil}
  def get_attr_values(opts) do
    scopes_nested = add_precomputed_values!(opts[:scopes])
    scopes_flat = flatten_scopes(scopes_nested)
    gettext = Keyword.get(opts, :gettext_module)

    {scopes_nested, scopes_flat, gettext}
  end

  # return a list of unique values assigned to given key. Returns a list
  # of tuples with unique combinations when a list of keys is given.
  def assigned_values(scopes, key) when is_atom(key) or is_binary(key),
    do: scopes |> assigned_values([key]) |> Stream.map(&elem(&1, 0)) |> Enum.uniq()

  def assigned_values(scopes, keys) when is_list(keys) do
    scopes |> aggregate_assigns(keys) |> Enum.uniq()
  end

  # takes a nested map of maps and returns a flat map with concatenated keys, aliases and prefixes.
  def flatten_scopes(scopes), do: scopes |> do_flatten_scopes() |> List.flatten() |> Map.new()

  def do_flatten_scopes(scopes, parent \\ {nil, nil}) do
    Enum.reduce(scopes, [], fn
      {_, scope_opts} = full_scope, acc ->
        new_scope = flatten_scope(full_scope, parent)
        flattened_subtree = do_flatten_scopes(scope_opts.scopes, new_scope)

        [[new_scope | flattened_subtree] | acc]
    end)
  end

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

  def get_slug_key(slug), do: slug |> String.replace("/", "_") |> String.replace_prefix("_", "")

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

  def aggregate_assigns(scopes, keys, acc \\ []) do
    scopes
    |> Enum.reduce(acc, fn
      {_slug, %{assign: assign}}, acc ->
        [get_values(assign, keys) | acc]
    end)
    |> List.flatten()
    |> Enum.uniq()
  end

  defp get_values(assign, keys),
    do: List.to_tuple(for(key <- keys, do: Map.get(assign, key)))

  def validate_config!(opts) do
    opts
    |> validate_matching_assign_keys!()
    |> validate_lang_keys!()
    |> validate_root_slug!()

    :ok
  end

  defp get_first_scope(scopes), do: scopes |> Map.to_list() |> hd() |> elem(1)

  defp get_sorted_assigns_keys(%{assign: assign}) when is_map(assign),
    do: assign |> Map.keys() |> Enum.sort()

  defp get_sorted_assigns_keys(_scope_opts), do: []

  # checks whether the scopes has a top level "/" (root) slug
  def validate_root_slug!(%{scopes: scopes} = _opts) do
    unless Enum.any?(scopes, fn {_scope, scope_opts} -> scope_opts.scope_prefix == "/" end),
      do: raise(MissingRootSlugError)
  end

  # assign keys should match in order to have uniform availability
  def validate_matching_assign_keys!(%{scopes: _scopes} = opts) do
    first_assigns_keys = opts.scopes |> get_first_scope() |> get_sorted_assigns_keys()

    validate_matching_assign_keys!(opts, first_assigns_keys)

    opts
  end

  def validate_matching_assign_keys!(%{scopes: scopes}, keys) do
    Enum.each(scopes, fn scope ->
      validate_matching_assign_keys!(scope, keys)
    end)
  end

  def validate_matching_assign_keys!({scope, scope_opts}, keys) do
    assigns_keys = get_sorted_assigns_keys(scope_opts)

    if Map.get(scope_opts, :scopes), do: validate_matching_assign_keys!(scope_opts, keys)

    if assigns_keys != keys,
      do:
        raise(AssignsMismatchError,
          scope: scope,
          expected_keys: keys,
          actual_keys: assigns_keys
        )
  end

  # when gettext_module is set, assigns should include the :locale key
  def validate_lang_keys!(opts) when not is_map_key(opts, :gettext_module), do: opts
  def validate_lang_keys!(%{gettext_module: nil} = opts), do: opts

  def validate_lang_keys!(%{gettext_module: mod, scopes: scopes} = opts) do
    scope = get_first_scope(scopes)

    if is_atom(mod) && is_binary(Map.get(scope.assign, :locale)),
      do: opts,
      else: raise(MissingLocaleAssignError)
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
          LiveHelpers.on_mount(
            unquote(caller.module),
            params,
            session,
            socket
          )
        end
      end

    Module.create(mount_module, contents, Macro.Env.location(env))
  end

  @spec gettext_in_compilers? :: boolean
  def gettext_in_compilers? do
    Mix.Project.get!().project()
    |> Access.get(:compilers)
    |> Enum.member?(:gettext)
  end

  @spec print_compile_header(
          caller :: Macro.Env.t(),
          gettext_in_compilers? :: boolean,
          opts :: PhxLocalizedRoutes.opts()
        ) :: no_return
  def print_compile_header(caller, gettext_in_compilers?, config_mod) do
    unless is_nil(config_mod[:gettext_module]) or gettext_in_compilers? do
      require Logger

      router_module =
        caller.module
        |> Module.split()
        |> List.first()
        |> Kernel.<>(".Router")

      Logger.warn(
        "When route translations are updated, run `mix compile --force #{router_module}`"
      )
    end
  end
end
