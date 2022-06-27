defmodule PhxLocalizedRoutes do
  @moduledoc """
  Macro to create and validate `PhxLocalizedRoutes` configuration modules with
  convenience callbacks to fetch specific values. For maximum performance, most
  callbacks return precompiled values with precomputed additional data.

  When used with an app depending on `Phoenix.LiveView` it also creates a LiveHelper module.

  For information how to use see the [Usage Guide](USAGE.md)
  """

  alias __MODULE__.Private

  @type opts :: [
          scopes: %{binary => opts_scope},
          gettext_module: module
        ]
  @type opts_scope :: %{
          optional(:assign) => %{atom => any},
          optional(:scopes) => %{binary => opts_scope}
        }

  # define callbacks
  @doc "Returns the scopes in a flat structure"
  @callback scopes :: %{(binary | nil) => PhxLocalizedRoutes.Scope.Flat.t()}

  @doc "Returns the scopes in a nested structure"
  @callback scopes_nested :: %{(binary | nil) => PhxLocalizedRoutes.Scope.Nested.t()}

  @doc "Returns the scope of given scope helper"
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
  @callback assigned_values(key_or_keys :: atom | String.t() | list(atom | String.t())) :: list

  @doc "Returns the configuration with precomputed values and flattened scopes"
  @callback config :: PhxLocalizedRoutes.Config.t()

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
  alias PLR.Scopes

  require Logger

  # type aliases
  @type caller :: Macro.Env.t()
  @type env :: Macro.Env.t()
  @type opts :: PLR.opts()

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
    scopes_nested = Scopes.add_precomputed_values!(opts[:scopes])
    config = Config.new!([{:scopes_nested, scopes_nested} | opts])

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
        do: PhxLocalizedRoutes.Scopes.assigned_values(@scopes_flat, key_or_keys)
    end
  end

  @spec create_live_helper_module(caller_module :: module, env) ::
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
end
