compile_peg_task = "tasks/compile.peg.exs"
if File.exists?(compile_peg_task) do
  Code.eval_file "tasks/compile.peg.exs"
end

defmodule Conform.Mixfile do
  use Mix.Project

  def project do
    [app: :conform,
     version: "0.10.0",
     elixir: "~> 0.15.0",
     escript: [main_module: Conform],
     compilers: [:peg, :erlang, :elixir, :app],
     description: description,
     package: package,
     deps: deps(Mix.env)]
  end

  def application do
    [applications: []]
  end

  defp deps(:dev), do: [{:neotoma, github: "seancribbs/neotoma"}]
  defp deps(_),    do: []

  defp description, do: "Easy release configuration for Elixir apps."
  defp package do
    [ files: ["lib", "src", "priv", "mix.exs", "README.md", "LICENSE"],
      contributors: ["Paul Schoenfelder"],
      licenses: ["MIT"],
      links: [ { "GitHub", "https://github.com/bitwalker/conform" } ] ]
  end
end
