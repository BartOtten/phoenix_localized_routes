defmodule PhxLocalizedRoutes.LiveHelpers do
  @moduledoc """
  Provides helpers for Phoenix LiveView applications

  ### Usage
  Instructions how to use this module can be found in the [Usage Guide](USAGE.md).
  """

  alias Phoenix.LiveView.Socket
  alias PhxLocalizedRoutes.Config
  require Logger

  defmacrop assign_code(conf, params, session, socket) do
    {:ok, phx_version} = :application.get_key(:phoenix, :vsn)

    if Version.match?(to_string(phx_version), "< 1.7.0-dev") do
      quote bind_quoted: [conf: conf, params: params, session: session, socket: socket] do
        {:cont,
         Phoenix.LiveView.assign(socket, %{loc: get_assigns(conf, params, session, socket)})}
      end
    else
      quote bind_quoted: [conf: conf, params: params, session: session, socket: socket] do
        {:cont,
         Phoenix.Component.assign(socket, %{loc: get_assigns(conf, params, session, socket)})}
      end
    end
  end

  @doc """
  Assigns custom assigns from the config into the socker under the `:loc` key. The
  configuration module is passed as the first argument.

  The assigns can used as `@loc.my_custom_assign`

  Used in `PhxLocalizedRoutes.create_helper_module/2`

  See also:
  - `Phoenix.LiveView.on_mount/1`

  """
  @spec on_mount(Config.t(), params :: map, session :: map, Socket.t()) :: {:cont, Socket.t()}
  def on_mount(conf, params, session, socket) do
    Logger.debug("Mount using `on_mount/4` from `#{__MODULE__}`")
    assign_code(conf, params, session, socket)
  end

  defp get_assigns(_conf, _params, _session, %Socket{
         private: %{connect_info: %{private: %{phx_loc_routes: %{assign: assigns}}}}
       }) do
    Logger.debug("Using assigns from private :phx_loc_routes in Socket")
    assigns
  end

  defp get_assigns(conf, _params, %{"scope_helper" => scope_helper} = _session, _socket) do
    Logger.debug("Using #{scope_helper}'s assigns from config using session key \"scope_helper\"")
    conf.get_scope(scope_helper).assign
  end
end
