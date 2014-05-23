defmodule Mix.Tasks.Conform.Release do
  @moduledoc """
  This is an internal mix task, meant to be consumed via exrm. Do not use.
  """
  @shortdoc false

  use Mix.Task

  def run(_) do
    conform_path = Path.join(Mix.Project.config |> Keyword.get(:deps_path), "conform") |> Path.expand
    escript_path = Path.join(conform_path, "conform")
    current_path = File.cwd!
    # Switch to conform directory
    File.cd! conform_path
    # Run escript task
    result = case Mix.Shell.cmd("mix escriptize", fn _ -> nil end) do
      0 -> escript_path
      _ -> {:error, "Failed to generate escript."}
    end
    File.cd! current_path
    result
  end
end