defmodule Periodic.MixProject do
  use Mix.Project

  @description """
  Run functions periodically: each function can be called on a different schedule.
  """

  @source_url "https://github.com/pragdave/periodic"

  @package [
      files:    ~w( lib README.md license.md ),
      licenses:   [ "BSD3" ],
      links:     %{ "GitHub" => @source_url }
  ]

  def project do
    [
      app:     :periodic,
      version: "0.1.0",
      elixir:  "~> 1.6",
      deps:    [ {:ex_doc, "~> 0.14", only: :dev} ],

      description: @description,
      package:     @package,
      source_url:  @source_url,

      start_permanent: Mix.env() == :prod,
    ]
  end

  def application do
    [
      mod: {Periodic.Application, []}
    ]
  end

end
