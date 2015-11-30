defmodule Mix.Tasks.Conform.Release do
  @moduledoc """
  This is an internal mix task, meant to be consumed via exrm. Do not use.
  """
  @shortdoc false

  use Mix.Task
  alias Conform.Utils

  def run(_) do
    # The goal here is to build the conform escript, so that exrm can
    # bundle it in a release
    case Mix.Dep.loaded([]) do
      [] ->
        with_conform extract_paths, fn _ ->
          build_escript
        end
      deps ->
        conform = deps |> Enum.find(fn
          %Mix.Dep{app: :conform} -> true
          _ -> false
        end)
        with_conform extract_paths(conform), fn _ ->
          build_escript
        end
    end
  end

  # Extract the conform dep directory, and it's build directory, from either
  # A Mix.Dep struct, or reconstructed from Mix.Project.deps_config
  defp extract_paths(), do: extract_paths(nil)
  defp extract_paths(nil) do
    conform_path = Path.expand(__ENV__.file) |> Path.dirname |> Path.join("../../../../conform")
    build_path   = Mix.Project.deps_config |> Keyword.get(:build_path) |> Path.join("lib") |> Path.join("conform")
    unless File.exists?(conform_path) do
      Utils.error "Failed to locate conform dependency!"
      exit(1)
    end
    %{conform: conform_path, build_path: build_path}
  end
  defp extract_paths(%Mix.Dep{opts: opts}) do
    conform_path = opts |> Keyword.get(:dest)
    build_path   = opts |> Keyword.get(:build)
    %{conform: conform_path, build_path: build_path}
  end

  # Custom version of Mix.Dep.in_dependency
  defp with_conform(%{conform: conform_path, build_path: build_path}, fun) do
    # Set the app_path to be the one stored in the dependency.
    # This is important because the name of application in the
    # mix.exs file can be different than the actual name and we
    # choose to respect the one in the mix.exs
    config = Mix.Project.deps_config
    config = Keyword.put(config, :app_path, build_path)

    Mix.Project.in_project(:conform, conform_path, config, fun)
  end

  # Builds the conform escript and returns the path
  defp build_escript() do
    escript_path = Path.join(File.cwd!, "conform")
    # Run escript task
    Mix.Task.load_all
    Mix.Task.run("escript.build")
    escript_path
  end
end
