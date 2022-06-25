defmodule PhxLocalizedRoutes.Scope.Nested do
  @moduledoc """
  Struct for scope with optionally nested scopes
  """
  @type t :: %__MODULE__{
          assign: %{atom => any} | nil,
          scopes: %{(binary | atom) => t} | nil,
          scope_path: list(binary),
          scope_prefix: binary,
          scope_alias: atom
        }
  @type kv_tuple :: {binary | nil, t}
  @type kv_map :: %{(binary | nil) => t}

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
  Struct for flattened scope
  """
  @type t :: %__MODULE__{
          assign: %{atom => any} | nil,
          scope_path: list(binary),
          scope_prefix: binary,
          scope_alias: atom
        }
  @type kv_tuple :: {binary | nil, t}
  @type kv_map :: %{(binary | nil) => t}

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
  @type gettext :: module | nil
  @type scopes :: PhxLocalizedRoutes.Scope.Flat.kv_map()
  @type t :: %__MODULE__{
          scopes: scopes,
          gettext_module: gettext
        }

  @enforce_keys [:scopes]
  defstruct [:scopes, :gettext_module]
end
