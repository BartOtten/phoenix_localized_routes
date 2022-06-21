defmodule PhxLocalizedRoutes.Plug do
  @moduledoc """
  Plug to put the scope helper in the session. The scope helper in the
  session can be used by `PhxLocalizedRoutes.LiveHelpers.on_mount/4` to
  get the current scope assigns.

  ### Usage
  Instructions how to use this module can be found in the [Usage Guide](USAGE.md).
  """
  @behaviour Plug

  alias Plug.Conn
  require Logger

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Conn{private: %{phx_loc_routes: %{assign: %{scope_helper: helper}}}} = conn, _opts) do
    Logger.debug("Put scope helper '#{helper}' in conn session")
    Conn.put_session(conn, :scope_helper, helper)
  end

  def call(conn, _opts) do
    conn
  end
end
