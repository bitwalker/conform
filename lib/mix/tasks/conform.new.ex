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
      # Execute task for each project in the umbrella
      for %Mix.Dep{app: app, opts: opts} <- Mix.Dep.Umbrella.loaded do
        Mix.Project.in_project(app, opts[:path], config, fn _ ->
          do_run(app, Path.expand("config/config.exs"))
        end)
      end
    else
      app = Mix.Project.config |> Keyword.get(:app)
      do_run(app, Path.expand("config/config.exs"))
    end
  end

  defp do_run(app, config_path) do
    output_path = Path.join([File.cwd!, "config", "#{app}.schema.exs"])
    # Load the configuration for this app, and
    # convert configuration to schema format
    config = Mix.Config.read!(config_path)
    schema = Conform.Schema.from_config(config)
    # Load configuration from dependencies, then
    # output configuration to `output_path`
    Conform.Schema.coalesce
    |> Conform.Schema.merge(schema)
    |> Conform.Schema.write_quoted(output_path)
    info "The generated schema for your project has been placed in config/#{app}.schema.exs"
  end

end
