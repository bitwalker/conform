defmodule Mix.Tasks.Conform.Release do
  @moduledoc """
  This is an internal mix task, meant to be consumed via exrm. Do not use.
  """
  @shortdoc false

  use Mix.Task

  def run(_) do
    [dep] = Mix.Dep.loaded_by_name([:conform], [])
    result = Mix.Dep.in_dependency dep, [], fn _ ->
      escript_path = Path.join(File.cwd!, "conform")
      # Run escript task
      case Mix.Shell.cmd("mix escriptize", fn _ -> nil end) do
        0 -> escript_path
        _ -> {:error, "Failed to generate escript."}
      end
    end
    result
  end
end