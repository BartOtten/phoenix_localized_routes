defmodule PhxLocalizedRoutes.Config do
  @moduledoc """
  Module to create and validate a Config struct
  """
  alias PhxLocalizedRoutes.Exceptions
  alias PhxLocalizedRoutes.Scope
  alias PhxLocalizedRoutes.Scopes

  @type t :: %__MODULE__{
          scopes: %{(binary | nil) => PhxLocalizedRoutes.Scope.Flat.t()},
          gettext_module: module | nil,
          sigil: String.t() | nil,
          sigil_original: String.t() | nil
        }
  @typep scope :: Scope.Flat.t()
  @typep scopes :: %{(binary | nil) => scope}
  @typep scope_tuple :: {binary | nil, scope}

  @enforce_keys [:scopes]
  defstruct [:scopes, :gettext_module, :sigil, :sigil_original]

  @doc false
  @spec new!(keyword) :: t()
  def new!(opts) do
    scopes_flat = opts |> Keyword.get(:scopes_nested) |> Scopes.flatten()
    gettext = Keyword.get(opts, :gettext_module)
    sigil = Keyword.get(opts, :sigil, "l")
    sigil_original = Keyword.get(opts, :sigil_original, nil)

    __MODULE__
    |> struct(%{
      scopes: scopes_flat,
      gettext_module: gettext,
      sigil: sigil,
      sigil_original: sigil_original
    })
    |> validate!()
  end

  @doc false
  @spec validate!(t) :: t
  def validate!(%__MODULE__{} = config) do
    ^config =
      config
      |> validate_root_slug!()
      |> validate_matching_assign_keys!()
      |> validate_lang_keys!()

    config
  end

  # checks whether the scopes has a top level "/" (root) slug
  @doc false
  @spec validate_root_slug!(t) :: t
  def validate_root_slug!(%__MODULE__{scopes: scopes} = opts) do
    unless Enum.any?(scopes, fn {_scope, scope_opts} -> scope_opts.scope_prefix == "/" end),
      do: raise(Exceptions.MissingRootSlugError)

    opts
  end

  # assign keys should match in order to have uniform availability
  @doc false
  @spec validate_matching_assign_keys!(t) :: t
  def validate_matching_assign_keys!(%__MODULE__{scopes: %{nil: reference_scope} = scopes} = opts) do
    reference_keys = get_sorted_assigns_keys(reference_scope)

    Enum.each(scopes, fn
      {nil, ^reference_scope} = _reference_scope ->
        :noop

      scope ->
        ^scope = validate_matching_assign_keys!(scope, reference_keys)
    end)

    opts
  end

  @doc false
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

  @doc false
  @spec validate_lang_keys!(t) :: t
  def validate_lang_keys!(%__MODULE__{gettext_module: nil} = opts), do: opts

  def validate_lang_keys!(%__MODULE__{gettext_module: mod, scopes: scopes} = opts) do
    scope = get_first_scope(scopes)

    unless is_atom(mod) && is_binary(Map.get(scope.assign, :locale)),
      do: raise(Exceptions.MissingLocaleAssignError)

    opts
  end

  @spec get_first_scope(scopes) :: scope
  defp get_first_scope(scopes), do: scopes |> Map.to_list() |> hd() |> elem(1)

  @spec get_sorted_assigns_keys(map) :: list()
  defp get_sorted_assigns_keys(%{assign: assign}) when is_map(assign),
    do: assign |> Map.keys() |> Enum.sort()

  defp get_sorted_assigns_keys(_scope_opts), do: []
end
