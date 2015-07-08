defmodule Mix.Tasks.Conform.Effective do
  @moduledoc """
  Print the effective configuration for the current project, either
  in it's entirety, or for a specific app, or setting

  ## Examples

      # Output the entire effective configuration
      mix conform.effective

      # Output the effective configuration for an application
      mix conform.effective --app myapp

      # Output the effective configuration for a specific setting
      mix conform.effective --key myapp.key.subkey

      # Output the effective configuration for a specific environment
      mix conform.effective --env prod

      # Output the effective schema for this application. Note that this includes schemas inherited from dependencies
      mix conform.effective --schema

      # output to a file instead of to stdout
      mix conform.effective --out sys.config

  Usage of `--app`, `--key` and ``--schema` options is mutually exclusive, but `--env` can be
  provided for all three use cases.

  """
  @shortdoc "Print the effective configuration for the current project"

  use    Mix.Task
  import Conform.Utils

  # Perform some actions within the context of a specific mix environment
  defp with_env(env, fun) do
    old_env = Mix.env
    try do
      # Change env
      Mix.env(env)
      fun.()
    after
      # Change back
      Mix.env(old_env)
    end
  end

  def run(args) do
    if Mix.Project.umbrella? do
      config = [build_path: Mix.Project.build_path]
      for %Mix.Dep{app: app, opts: opts} <- Mix.Dep.Umbrella.loaded do
        Mix.Project.in_project(app, opts[:path], config, fn _ -> do_run(args |> parse_args) end)
      end
    else
      do_run(args |> parse_args)
    end
  end

  defp do_run(args) do
    app       = Mix.Project.config |> Keyword.get(:app)
    conf_path = Path.join([File.cwd!, "config", "#{app}.conf"])
    # Load the base configuration from config.exs if it exists, and validate it
    # If config.exs doesn't exist, proceed if a .conf file exists, otherwise there
    # is no configuration to display
    config = case File.exists?("config/config.exs") do
      true ->
        # Switch environments when reading the config
        with_env args.env, fn ->
          Path.join([File.cwd!, "config", "config.exs"]) |> Mix.Config.read!
        end
      false -> []
    end
    # Read .conf
    conf = case File.exists?(conf_path) do
      true  -> conf_path |> Conform.Parse.file
      false -> []
    end
    # Load merged schemas
    app_schema = Conform.Schema.schema_path(app) |> Conform.Schema.load! |> Dict.delete(:import)
    schema = Conform.Schema.coalesce |> Conform.Schema.merge(app_schema)
    # Translate .conf -> config, using settings from config if one is
    # not provided in the .conf. If no setting is present in either
    # the config, or the .conf, the default from the schema is used.
    effective = Conform.Translate.to_config(config, conf, schema)
    # Print the configuration as requested
    output = case args.options.type do
      :schema -> Conform.Schema.stringify(schema)
      :all -> Conform.Config.pretty(effective)
      :app ->
        case effective |> Keyword.get(args.options.app) do
          nil        ->
            notice "App not found!"
            ""
          app_config ->
            Conform.Config.pretty(app_config)
        end
      :key ->
        effective |> extract_key(args.options.key) |> Conform.Config.pretty
    end

    case args.options.output do
      :stdout ->
        Conform.Config.print_raw output
      path ->
        path |> File.write!(output)
    end
  end

  defp extract_key(config, path) do
    # Split the path specification into a get_in spec
    spec = path |> String.split(".", trim: true) |> Enum.map(&String.to_atom/1)
    # Extract value
    try do
      config |> get_in(spec)
    rescue
      Protocol.UndefinedError ->
        notice "The value for some key in #{path} doesn't implement the Access protocol!"
        exit(:normal)
    end
  end

  defp parse_args(argv) do
    {args, _, _} = OptionParser.parse(argv)
    env = args |> Keyword.get(:env, "#{Mix.env}") |> String.to_atom
    app = args |> Keyword.get(:app)
    key = args |> Keyword.get(:key)
    schema = args |> Keyword.get(:schema)
    output = args |> Keyword.get(:out, :stdout)

    mutually_exclusive_opts = Enum.filter([app: app, key: key, schema: schema], fn({_, val}) -> val != nil end)
    if Enum.count(mutually_exclusive_opts) > 1 do
      error "the options #{mutually_exclusive_opts} are mutually exclusive"
      exit(:normal)
    end

    # populate options
    options = case {app, key, schema} do
      {nil, nil, nil}  -> %{:type => :all}
      {_, _, true} -> %{:type => :schema}
      {^app, _, _} -> %{:type => :app, :app => app |> String.to_atom}
      {_, ^key, _} -> %{:type => :key, :key => key}
    end
    options = Map.put(options, :output, output)

    # Make sure env is a valid value
    unless env in [:test, :dev, :prod] do
      error "The value provided for --env is not a valid environment"
      exit(:normal)
    end
    %{:env => env, :options => options}
  end
end
