defmodule Conform.Mixfile do
  use Mix.Project

  @compile_peg_task "tasks/compile.peg.exs"
  @do_peg_compile?  File.exists?(@compile_peg_task)
  if @do_peg_compile? do
    Code.eval_file @compile_peg_task
  end

  def project do
    embed_elixir? =
      if System.get_env("EMBED_ELIXIR") == "false" do
        false
      else
        true
      end

    [app: :conform,
     version: "2.5.2",
     elixir: "~> 1.3",
     escript: [main_module: Conform, path: "priv/bin/conform", embed_elixir: embed_elixir?],
     compilers: compilers(@do_peg_compile?),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     docs: docs(),
     deps: deps()]
  end

  def application do
    [applications: [:neotoma]]
  end

  defp compilers(true), do: [:peg, :erlang, :elixir, :app]
  defp compilers(_),    do: nil

  defp deps do
    [{:neotoma, "~> 1.7.3"},
     {:ex_doc, "~> 0.13", only: :dev}]
  end

  defp description, do: "Easy, powerful, and extendable configuration tooling for releases."
  defp package do
    [files: ["lib", "src", "priv", "mix.exs", "README.md", "LICENSE"],
     maintainers: ["Paul Schoenfelder"],
     licenses: ["MIT"],
     links: %{ "GitHub": "https://github.com/bitwalker/conform" }]
  end
  defp docs do
    [main: "getting-started",
     extras: [
       "docs/Getting Started.md",
       "docs/Custom Types.md",
       "docs/Integrating with Distillery.md"
     ]]
  end
end
