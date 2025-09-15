defmodule ReactiveStruct.MixProject do
  use Mix.Project

  def project do
    [
      app: :reactive_struct,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Documentation
      name: "ReactiveStruct",
      description: "An Elixir library for defining reactive structs",
      source_url: "https://github.com/chgeuer/reactive_struct",
      homepage_url: "https://github.com/chgeuer/reactive_struct",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "ReactiveStruct",
      # logo: "assets/static/images/logo.png",
      extras: [
        "README.md": [title: "Overview"]
        # "CHANGELOG.md": [title: "Changelog"]
      ],
      groups_for_modules: [
        "Core Logic": [
          ReactiveStruct
        ]
      ],
      # skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      markdown_processor: ExDoc.Markdown.Earmark,
      source_ref: "main",
      formatters: ["html", "epub"]
    ]
  end
end
