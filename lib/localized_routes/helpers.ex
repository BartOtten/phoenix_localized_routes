defmodule PhxLocalizedRoutes.Helpers do
  @moduledoc """
  Helpers to be used in views and controllers.
  """
  alias PhxLocalizedRoutes.Helpers.Private
  alias PhxLocalizedRoutes.Scope

  @doc ~S"""
  Marco used to wrap a Phoenix route and transform it into a localized
  route. The localized routes use the `:scope_helper` to alter
  the destination (alias) of the route on render.

  By default it uses the `scope_helper` from `Phoenix.LiveView.Socket` or `Plug.Conn`, keeping
  the user in it's current locale / scope. A custom `:scope_helper` can be provided through
  assigns in `loc_opts`.

  **Example**

  ```elixir
  Routes.product_index_path(@socket, :index)
  /products

  loc_opts = %{assigns: %{scope_helper: "eu_nl"}}
  loc_route(Routes.product_index_path(@socket, :index), loc_opts)
  /eu/nl/products
  ```

  When no `:scope_helper` is found or when no matching helper function is exported, an
  error is logged and the original link will be returned.

  **Example: Generate links to all other localized routes of the product index**

  ```elixir
  <!-- ExampleWeb.LocalizedRoutes is aliased as Loc in view_helpers() -->
  <!-- loc_route is imported from PhxLocalizedRoutes.Helpers -->
  <%= for {slug, opts} <- Loc.scopes(), opts.assigns.scope_helper != @loc.scope_helper do %>
      <span>
        <%= link " [#{slug}] ", to: loc_route(Routes.product_index_path(@socket, :index), opts) %></span>
  <% end %>
  ```
  """
  @spec loc_route(orig_route :: Macro.t(), loc_opts :: Scope.Flat.t() | nil) ::
          Macro.output()
  defmacro loc_route(orig_route, loc_opts \\ nil) do
    {helper_module, orig_helper_fn, conn_or_socket, args} = Private.fetch_vars(orig_route)

    quote bind_quoted: [
            orig_route: orig_route,
            helper_module: helper_module,
            orig_helper_fn: orig_helper_fn,
            conn_or_socket: conn_or_socket,
            args: args,
            loc_opts: loc_opts
          ] do
      scope = Private.get_scope_helper(loc_opts || conn_or_socket)

      case Private.localize_route(helper_module, orig_helper_fn, args, scope) do
        {:ok, :original} ->
          orig_route

        {:ok, loc_route} ->
          loc_route

        {:error, msg} ->
          Private.log_error(msg)
          orig_route
      end
    end
  end
end

defmodule PhxLocalizedRoutes.Helpers.Private do
  @moduledoc false

  alias Phoenix.LiveView.Socket
  alias PhxLocalizedRoutes.Scope
  alias Plug.Conn

  require Logger

  def localize_route(_helper_module, _orig_helper_fn, _args, nil = _scope),
    do: {:ok, :original}

  def localize_route(helper_module, orig_helper_fn, args, scope) do
    # There is no guarantee the helper function exists nor that the function
    # accepts the arguments passed into it. Therefor we catch any ArgumentError
    # and rescue with the original function.

    helper_fn = helper_fn(orig_helper_fn, scope)

    if fn_exists?(helper_module, helper_fn, args) do
      try do
        {:ok, apply(helper_module, helper_fn, args)}
      rescue
        ArgumentError ->
          {:error, "Failed to apply #{helper_module}.#{helper_fn}() with #{inspect(args)}"}
      end
    else
      {:error, "#{helper_module}.#{helper_fn} does not exist"}
    end
  end

  def get_scope_helper(%Scope.Flat{assign: %{scope_helper: helper}}),
    do: helper

  def get_scope_helper(%Socket{assigns: %{__assigns__: %{loc: %{scope_helper: helper}}}}),
    do: helper

  def get_scope_helper(%Conn{assigns: %{loc: %{scope_helper: helper}}}), do: helper

  def get_scope_helper(unmatched) do
    Logger.warning("`get_scope_helper/1` could not find a scope. Returns `nil`")

    Logger.debug(
      "`get_scope_helper/1` did not find key :scope_helper in:\n\n#{inspect(unmatched, limit: :infinity, structs: false)}\n"
    )

    nil
  end

  # Elixir >= 1.14
  def fetch_vars(
        {_ma1, _me1,
         [
           _ma2,
           {{_marker, _meta, [helper_module, orig_helper_fn]}, _meta2,
            [conn_or_socket | _rest] = args}
         ]}
      ) do
    {helper_module, orig_helper_fn, conn_or_socket, args}
  end

  # Elixir <= 1.13
  def fetch_vars(
        {{_marker, _meta, [helper_module, orig_helper_fn]}, _meta2,
         [conn_or_socket | _rest] = args}
      ) do
    {helper_module, orig_helper_fn, conn_or_socket, args}
  end

  @doc """
    Given the original helper function name and a string prefix returns an
    alternative helper function name. When the alternative helper function does
    not exists the original function name is returned.

    ## Examples:

      iex> PhxLocalizedRoutes.Helpers.Private.helper_fn(:page, "europe_nl")
      :europe_nl_page
  """

  def helper_fn(orig_helper_fn, nil), do: orig_helper_fn

  def helper_fn(orig_helper_fn, scope) when is_binary(scope) do
    str_original = Atom.to_string(orig_helper_fn)
    String.to_existing_atom(scope <> "_" <> str_original)
  rescue
    ArgumentError ->
      orig_helper_fn
  end

  # Wrapped Logger so no import is needed in the macro module
  def log_error(message) do
    Logger.error(message)
  end

  def fn_exists?(mod, func, args) do
    # using ultra fast pattern matching, fallback to slower length/1
    arity =
      case args do
        [_, _] -> 2
        [_, _, _] -> 3
        [_, _, _, _] -> 4
        [_ | _] = unmatched -> return_unmatched(unmatched)
      end

    Kernel.function_exported?(mod, func, arity)
  end

  def return_unmatched(unmatched) when is_list(unmatched),
    do:
      unmatched
      |> length
      |> tap(&Logger.warn("Unmatched arity of #{&1} used in #{__MODULE__}"))
end
