defmodule Mix.Tasks.Conform.New do
  @moduledoc """
  Create a new .schema.exs file for configuring your app with conform.

  The schema will be output to config/<yourapp>.schema.exs. See the conform
  docs for help on how to modify this file. Once you are ready to generate
  your apps config from the schema, see the help for `mix conform.configure`.

  """
  @shortdoc "Create a new .schema.exs file for configuring your app with conform."

  use    Mix.Task
  import Conform.Utils

  def run(_args) do
    if Mix.Project.umbrella? do
      config = [build_path: Mix.Project.build_path]
      # Collect a list of absolute paths to all config files for the umbrella
      app_configs =
        Mix.Dep.Umbrella.loaded
        |> Enum.flat_map(fn %Mix.Dep{app: app, opts: opts} ->
            Mix.Project.in_project(app, opts[:path], config, fn _ -> Mix.Project.config_files end)
            |> Enum.reject(&filter_config/1)
            |> Enum.map(fn c -> {app, Path.join(opts[:path], c) |> Path.expand} end)
           end)
      # Execute task for each project in the umbrella
      for %Mix.Dep{app: app, opts: opts} <- Mix.Dep.Umbrella.loaded do
        Mix.Project.in_project(app, opts[:path], config, fn _ -> do_run(app_configs) end)
      end
    else
      app = Mix.Project.config |> Keyword.get(:app)
      Mix.Project.config_files
      |> Enum.reject(&filter_config/1)
      |> Enum.map(fn c -> {app, c |> Path.expand} end)
      |> do_run
    end
  end

  defp do_run(app_configs) do
    app         = Mix.Project.config |> Keyword.get(:app)
    output_path = Path.join([File.cwd!, "config", "#{app}.schema.exs"])

    # Load the configuration for this app, and any apps which this app depends on
    deps = [{app, []} | (Mix.Project.config |> Keyword.get(:deps))]
    config = app_configs |> Enum.reduce([], fn {application, config_path}, result ->
      case deps |> Keyword.get(application) do
        nil ->
          result
        _ ->
          # Read in the config at `config_path`
          loaded = Mix.Config.read(config_path)
          # Merge the loaded config over the current config stored in `result`
          Mix.Config.merge(result, loaded)
      end
    end)

    # Convert configuration to schema format
    schema = Conform.Schema.from_config(config)

    # Output configuration to `output_path`
    output_path |> File.write!(schema |> stringify)
    info "The generated schema for your project has been placed in config/#{app}.schema.exs"
  end

  defp stringify(schema) do
    if schema == Conform.Schema.empty do
      schema
        |> Inspect.Algebra.to_doc(%Inspect.Opts{pretty: true})
        |> Inspect.Algebra.pretty(10)
    else
      contents = schema
        |> Inspect.Algebra.to_doc(%Inspect.Opts{pretty: true, limit: 1000})
        |> Inspect.Algebra.pretty(10)
        |> String.replace("[doc:", "[\n   doc:")
        |> String.replace("   ", "      ")
        |> String.replace("[\"", "[\n    \"")
        |> String.replace("],", "\n    ],")
        |> String.replace("[mappings", "[\n  mappings")
        |> String.replace("translations: []]", " translations: []\n]")
      Regex.replace(~r/\s+(\".*\"\: \[)/, contents, "\n    \\1")
    end
  end

  defp filter_config(config) do
    config |> String.ends_with?([".conf", ".schema.exs", "mix.exs", ".lock"])
  end

end