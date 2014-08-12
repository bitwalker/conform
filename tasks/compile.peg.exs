defmodule Mix.Tasks.Compile.Peg do
  @moduledoc """
  Compiles Erlang Parsing Expression Grammars (PEGs).
  """
  @shortdoc "Compiles Erlang Parsing Expression Grammars (PEGs)."

  use Mix.Task

  @recursive true
  @manifest  ".compile.peg"

  def run(_) do
    get_sources |> Enum.map(&compile_peg/1)
  end

  def clean do
    get_sources |> Enum.map(&do_clean/1)
  end

  defp get_sources() do
    source_paths = Mix.Project.config[:erlc_paths]
    Mix.Utils.extract_files(source_paths, [:peg])
  end

  defp compile_peg(source_path) do
    :neotoma.file('#{source_path |> Path.expand}')
    source_path
  end

  defp do_clean(source_path) do
    erl = String.replace(source_path, ".peg", ".erl")
    case File.exists?(erl) do
      true  -> File.rm!(erl)
      false -> true # Do nothing
    end
  end
end