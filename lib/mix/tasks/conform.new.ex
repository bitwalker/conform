defmodule Mix.Tasks.Conform.New do
  @moduledoc """
  Create a new .schema.exs file for configuring your app with conform.

  The schema will be output to config/<yourapp>.schema.exs. See the conform
  docs for help on how to modify this file. Once you are ready to generate
  your apps config from the schema, see the help for `mix conform.configure`.

  """
  @shortdoc "Create a new .schema.exs file for configuring your app with conform"

  use Mix.Task

  def run(_args) do
    Mix.Tasks.Loadpaths.run([])
    if Mix.Project.umbrella? do
      # Execute task for each project in the umbrella
      for %Mix.Dep{app: app, opts: opts} <- Mix.Dep.Umbrella.loaded do
        Mix.Project.in_project(app, opts[:path], opts, fn _ ->
          do_run(app, Path.expand("config/config.exs"))
        end)
      end
    else
      app = Mix.Project.config |> Keyword.get(:app)
      do_run(app, Path.expand("config/config.exs"))
    end
  end

  defp do_run(app, config_path) do
    # Load the configuration for this app, and convert configuration to schema format
    output_path = Conform.Schema.schema_path(app)
    # Make sure we want to proceed if a schema already exists
    continue? =
      if File.exists?(output_path) do
        confirm_overwrite?(output_path)
      else
        true
      end
    if continue? do
      # Ensure output directory exists
      output_path |> Path.dirname |> File.mkdir_p!
      if File.exists?(config_path) do
        # Load existing config and convert it to quoted schema terms
        config = Mix.Config.read!(config_path)
        schema = Conform.Schema.from_config(config)
        # Write the generated schema to `output_path`
        Conform.Schema.write_quoted(schema, output_path)
        Conform.Logger.success "The schema for your project has been placed in #{Path.relative_to_cwd(output_path)}"
      else
        Conform.Logger.warn "Your project does not currently have any configuration!"
        Conform.Schema.write_quoted(Conform.Schema.empty, output_path)
        Conform.Logger.success "An empty schema has been placed in #{Path.relative_to_cwd(output_path)}"
      end
    end
  end

  defp confirm_overwrite?(output_path) do
    IO.puts IO.ANSI.yellow
    confirmed? = Mix.Shell.IO.yes?("""
      You already have a schema at #{Path.relative_to_cwd(output_path)}.
      Do you want to overwrite this schema with a new one?
      """)
    IO.puts IO.ANSI.reset
    confirmed?
  end
end
