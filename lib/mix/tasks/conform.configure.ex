defmodule Mix.Tasks.Conform.Configure do
  @moduledoc """
  Create a .conf file based on your projects configuration schema

  This task will fail and alert you if you haven't generated your schema, or hand
  written one yet, and expects it to be located in config/<yourapp>.schema.exs.

  """
  @shortdoc "Create a .conf file based on your projects configuration and conform schema."

  use    Mix.Task
  import Conform.Utils

  def run(_args) do
    app         = Mix.Project.config |> Keyword.get(:app)
    output_path = Path.join([File.cwd!, "config", "#{app}.conf"])
    schema_path = Path.join([File.cwd!, "config", "#{app}.schema.exs"])

    # Convert configuration to schema format
    schema = Conform.Schema.load(schema_path)

    # Conver to .conf
    conf = Conform.Translate.to_conf(schema)

    # Output configuration to `output_path`
    output_path |> File.write!(conf)
    info "The .conf file for #{app} has been generated. You can find it in config/#{app}.conf"
  end
end