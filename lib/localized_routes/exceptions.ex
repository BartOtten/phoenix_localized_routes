defmodule PhxLocalizedRoutes.Exceptions do
  defmodule AssignsMismatchError do
    @moduledoc """
    Raised when the custom assigns of scopes do not have the same keys.

    ```elixir
    %{
      scopes: %{
        "/"      => %{assigns: %{key1: 1, key2: 2}},
        "/other" => %{assigns: %{key1: 1}} # missing :key2
      }
    }
    ```
    """

    defexception [:scope, :expected_keys, :actual_keys]

    @impl Exception
    def message(exception) do
      ~s"""
      assignment keys mismatch in local scope #{exception.scope}.\n
      Expected: #{inspect(exception.expected_keys)}
      Actual: #{inspect(exception.actual_keys)}
      """
    end
  end

  defmodule MissingLocaleAssignError do
    @moduledoc """
    Raised when gettext_module is set in the configuration but
    :locale is not set in the assigns.

    ```elixir
    %{
      scopes: %{
        "/"       =>    %{assigns: %{key1: 1}}, # missing :locale
        "/other"  =>    %{assigns: %{key1: 1}}},
      gettext_module: MyGettext
    }
    ```

    """

    @impl Exception
    defexception message:
                   "the configuration includes a gettext_module but the assigns are missing the :locale key"
  end

  defmodule MissingRootSlugError do
    @moduledoc """
    Raised when the scope map does not start with the root scope "/".

    ```elixir
    %{
      scopes: %{
        "/first"       =>    %{assigns: %{key1: 1}},
        "/other"  =>    %{assigns: %{key1: 1}}},
    }
    ```

    To fix this, include a scope for the root "/".

    ```elixir
    `%{
      scopes: %{
        "/" => %{
        assigns: %{level: 1}
        scopes:
          "/first"       =>    %{assigns: %{level: 2}},
          "/other"  =>    %{assigns: %{level: 2}}},
       }
    }
    ```

    """

    @impl Exception
    defexception message:
                   "the configured scopes do not start with a root slug. Please wrap your scopes in a root scope with key '/'"
  end
end
