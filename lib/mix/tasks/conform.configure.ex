defmodule Mix.Tasks.Conform.Configure do
  @moduledoc """
  Create a .conf file based on your projects configuration schema.
  """
  @shortdoc "Create a .conf file from schema and project config"

  use Mix.Task

  def run(args) do
    Mix.Tasks.Loadpaths.run([])
    if Mix.Project.umbrella? do
      for %Mix.Dep{app: app, opts: opts} <- Mix.Dep.Umbrella.loaded do
        Mix.Project.in_project(app, opts[:path], opts, &do_run/1)
      end
    else
      do_run(args)
    end
  end

  defp do_run(_) do
    app         = Mix.Project.config |> Keyword.get(:app)
    schema_path = Conform.Schema.schema_path(app)
    output_path = Path.join([File.cwd!, "config", "#{app}.#{Mix.env}.conf"])

    # Check for conditions which prevent us from continuing
    continue? =
      if File.exists?(schema_path) do
        if File.exists?(output_path) do
          confirm_overwrite?(output_path)
        else
          true
        end
      else
        Conform.Logger.error "You must create a schema before you can generate a .conf!"
      end

    if continue? do
      # Convert configuration to schema format
      schema = Conform.Schema.load!(schema_path)
      # Convert to .conf
      conf = Conform.Translate.to_conf(schema)
      # Output configuration to `output_path`
      File.write!(output_path, conf)
      Conform.Logger.success "The .conf file for #{app} has been placed in #{Path.relative_to_cwd(output_path)}"
    end
  end

  defp confirm_overwrite?(output_path) do
    IO.puts IO.ANSI.yellow
    confirmed? = Mix.Shell.IO.yes?("""
      You already have a .conf at #{Path.relative_to_cwd(output_path)}.
      Do you want to overwrite this config file with a new one?
      """)
    IO.puts IO.ANSI.reset
    confirmed?
  end
end
