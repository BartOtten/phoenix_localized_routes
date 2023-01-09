defmodule PhxLocalizedRoutes.MixProject do
  use Mix.Project

  @source_url "https://github.com/BartOtten/phoenix_localized_routes"
  @version "0.1.3"
  @name "Phoenix Localized Routes"

  def project do
    [
      app: :phoenix_localized_routes,
      version: @version,
      elixir: "~> 1.11",
      deps: deps() ++ dev_deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: compilers(Mix.env()),
      dialyzer: dialyzer(),
      # Docs
      name: @name,
      description: description(),
      source_url: @source_url,
      docs: docs(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "phx.routes": :test,
        compile: :test,
        "gettext.extract": :test,
        "gettext.merge": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    if Mix.env() == :test, do: Application.put_env(:phoenix, :json_library, Jason)

    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp compilers(:test), do: [:gettext] ++ Mix.compilers()
  defp compilers(_), do: Mix.compilers()

  defp dialyzer, do: [plt_add_apps: [:mix, :gettext, :phoenix_live_view]]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, ">= 1.6.0"},
      {:phoenix_live_view, ">= 0.16.0", optional: true},
      {:gettext, ">= 0.0.0", optional: true}
    ]
  end

  defp dev_deps do
    [
      {:jason, "~> 1.0", only: [:dev, :test], optional: true},
      {:ex_doc, "~> 0.28", only: [:dev, :test]},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.14", only: :test},
      {:floki, ">= 0.30.0", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:makeup_diff, "~> 0.1.0", only: [:dev]}
    ]
  end

  defp aliases do
    %{"phx.routes": "phx.routes MyAppWeb.MultiLangRouter"}
  end

  defp package do
    [
      maintainers: ["Bart Otten"],
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE.md
                CHANGELOG.md CONTRIBUTING.md USAGE.md),
      links: %{
        Changelog: "https://hexdocs.pm/phoenix_localized_routes/changelog.html",
        GitHub: "https://github.com/BartOtten/phoenix_localized_routes"
      }
    ]
  end

  defp description() do
    "Localize your Phoenix website with multilingual URLs and custom template assigns; enhancing user engagement and content relevance."
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      filter_modules: "PhxLocalizedRoutes",
      skip_undefined_reference_warnings_on: [
        "PhxLocalizedRoutes.LiveHelpers.on_mount/4"
      ],
      extras: ["README.md", "USAGE.md", "CHANGELOG.md"],
      groups_for_modules: [
        structs: [
          PhxLocalizedRoutes.Config,
          PhxLocalizedRoutes.Scope.Flat,
          PhxLocalizedRoutes.Scope.Nested
        ],
        exceptions: [
          PhxLocalizedRoutes.Exceptions,
          PhxLocalizedRoutes.Exceptions.MissingLocaleAssignError,
          PhxLocalizedRoutes.Exceptions.AssignsMismatchError,
          PhxLocalizedRoutes.Exceptions.MissingRootSlugError
        ]
      ]
    ]
  end
end
