defmodule ExWalmart.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/drdray1/ex_walmart"

  def project do
    [
      app: :ex_walmart,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [threshold: 90, summary: [threshold: 90]],

      # Hex
      description:
        "Elixir client for the Walmart Affiliate API — product search, lookup, stores, and add-to-cart links",
      package: package(),

      # Docs
      name: "ExWalmart",
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :public_key, :crypto]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:plug, "~> 1.14", only: :test}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "ExWalmart",
      extras: ["README.md"],
      groups_for_modules: [
        API: [
          ExWalmart.Search,
          ExWalmart.Items,
          ExWalmart.Catalog,
          ExWalmart.Taxonomy,
          ExWalmart.Stores,
          ExWalmart.Recommendations,
          ExWalmart.Reviews
        ],
        Links: [
          ExWalmart.Cart
        ],
        Client: [
          ExWalmart.Client,
          ExWalmart.Request,
          ExWalmart.Signature
        ]
      ]
    ]
  end
end
