defmodule Mix.Tasks.Conform.Configure do
  @moduledoc """
  Create a .conf file based on your projects configuration schema.
  """
  @shortdoc "Create a .conf file from schema and project config."

  use    Mix.Task
  import Conform.Utils

  def run(args) do
    if Mix.Project.umbrella? do
      config = [build_path: Mix.Project.build_path]
      for %Mix.Dep{app: app, opts: opts} <- Mix.Dep.Umbrella.loaded do
        Mix.Project.in_project(app, opts[:path], config, &do_run/1)
      end
    else
      do_run(args)
    end
  end

  defp do_run(_) do
    app         = Mix.Project.config |> Keyword.get(:app)
    schema_path = Conform.Schema.schema_path(app)
    output_path = Path.join([File.cwd!, "config", "#{app}.conf"])

    # Check for conditions which prevent us from continuing
    continue? = case File.exists?(schema_path) do
      true  -> true
      false ->
        error "You must create a schema before you can generate a .conf!"
        false
    end
    continue? = continue? and case File.exists?(output_path) do
      true  -> confirm_overwrite?(output_path)
      false -> true
    end

    if continue? do
      # Convert configuration to schema format
      schema = Conform.Schema.load!(schema_path)
      # Convert to .conf
      conf = Conform.Translate.to_conf(schema)
      # Output configuration to `output_path`
      File.write!(output_path, conf)
      info "The .conf file for #{app} has been placed in #{Path.relative_to_cwd(output_path)}"
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
