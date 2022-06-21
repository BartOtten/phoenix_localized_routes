defmodule Routes do
  defmacro __using__(opts \\ []) do
    loc_module = Keyword.get(opts, :loc_module)

    native_routes =
      quote do
        resources("/resources", PageController, except: [:delete])
        options("/pages/:page", PageController, :options)
        head("/pages/:page", PageController, :head)
        patch("/pages/:page", PageController, :update)
        get("/pages/new", PageController, :new, assigns: %{key: :value}, as: :new_pages)
        post("/pages", PageController, :create)
        put("/pages", PageController, :update)
        delete("/pages", PageController, :delete)
        # Live routes
        live("/", HomeLive, :index)
        live("/products", ProductLive.Index, :index)
        live("/products/new", ProductLive.Index, :new)
        live("/products/:id/edit", ProductLive.Index, :edit)
        live("/products/:id", ProductLive.Show, :show)
        live("/products/:id/show/edit", ProductLive.Show, :edit)
      end

    loc_routes =
      quote do
        localize unquote(loc_module) do
          unquote(native_routes)
        end
      end

    quote do
      use MyAppWeb, :router
      import Phoenix.LiveView.Router

      scope "/", MyAppWeb do
        unquote(if loc_module, do: loc_routes, else: native_routes)
      end
    end
  end
end

defmodule MyAppWeb.NativeRouter do
  use Routes
end

defmodule MyAppWeb.LocRouter do
  use Routes, loc_module: MyAppWeb.LocalizedRoutes
end

defmodule MyAppWeb.MultiLangRouter do
  use Routes, loc_module: MyAppWeb.MultiLangRoutes
end
