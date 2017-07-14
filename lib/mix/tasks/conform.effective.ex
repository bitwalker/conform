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

  use Mix.Task

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

  def run(argv) do
    args = parse_args(argv)
    cond do
      Mix.Project.umbrella? && args.options.type == :app ->
        app = args.options.app
        dep = Enum.find(Mix.Dep.Umbrella.loaded, fn %Mix.Dep{app: ^app} -> true; _ -> false end)
        case dep do
          %Mix.Dep{opts: opts} ->
            Mix.Project.in_project(app, opts[:path], opts, fn _ -> do_run(args) end)
          _ ->
            Conform.Logger.error "#{app} could not be found"
        end
      Mix.Project.umbrella? ->
        for %Mix.Dep{app: app, opts: opts} <- Mix.Dep.Umbrella.loaded do
          Conform.Logger.info "in #{app}"
          Mix.Project.in_project(app, opts[:path], opts, fn _ -> do_run(args) end)
        end
      :else ->
        do_run(args)
    end
  end

  defp do_run(args) do
    Mix.Tasks.Loadpaths.run([])

    project_config = Mix.Project.config()
    app = project_config[:app]
    config_path = Path.join(File.cwd!, "config")
    conf_path =
      case File.exists?(Path.join(config_path, "#{app}.#{args.env}.conf")) do
        true  -> Path.join(config_path, "#{app}.#{args.env}.conf")
        false -> Path.join(config_path, "#{app}.conf")
      end
    # Load the base configuration from config.exs if it exists, and validate it
    # If config.exs doesn't exist, proceed if a .conf file exists, otherwise there
    # is no configuration to display
    config =
      if File.exists?("config/config.exs") do
        # Switch environments when reading the config
        with_env args.env, fn ->
          Path.join([File.cwd!, "config", "config.exs"]) |> Mix.Config.read!
        end
      else
        []
      end
    # Read .conf
    conf =
      if File.exists?(conf_path) do
        case Conform.Conf.from_file(conf_path) do
          {:error, reason} when is_binary(reason) ->
            Conform.Logger.error "Failed to parse .conf!\nError: #{reason}"
          {:error, reason} ->
            Conform.Logger.error "Failed to parse .conf!\nError: #{inspect reason}"
          {:ok, table} ->
            table
        end
      else
        Conform.Logger.debug "No .conf file found - defaults from schema and Mix config will be used"
          {:ok, table} = Conform.Conf.from([])
          table
      end
    # Load merged schemas
    schema =
      app
      |> Conform.Schema.schema_path
      |> Conform.Schema.load!
    # Translate .conf -> config, using settings from config if one is
    # not provided in the .conf. If no setting is present in either
    # the config, or the .conf, the default from the schema is used.
    effective = Conform.Translate.to_config(schema, config, conf)
    # Print the configuration as requested
    output_type = args.options.output
    case args.options.type do
      :schema when output_type == :stdout ->
        schema |> Conform.Schema.stringify |> IO.puts
      :schema when is_binary(output_type) ->
        output = schema |> Conform.Schema.stringify
        File.write!(output_type, output)
      :all when output_type == :stdout ->
        Conform.SysConfig.print(effective)
      :all when is_binary(output_type) ->
        output = Conform.SysConfig.prettify(effective)
        File.write!(output_type, output)
      :app ->
        case Keyword.get(effective, args.options.app) do
          nil ->
            Conform.Logger.warn "App not found!"
            if is_binary(output_type) do
              File.touch(output_type)
            end
          app_config when output_type == :stdout ->
            Conform.SysConfig.print(app_config)
          app_config when is_binary(output_type) ->
            output = Conform.SysConfig.prettify(app_config)
            File.write!(output_type, output)
        end
      :key when output_type == :stdout ->
        config = effective |> extract_key(args.options.key)
        Conform.SysConfig.print(config)
      :key when is_binary(output_type) ->
        config = effective |> extract_key(args.options.key) |> Conform.SysConfig.prettify
        File.write!(output_type, config)
      _ ->
        Conform.Logger.error "Invalid output: #{inspect output_type}"
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
        Conform.Logger.error "The value for some key in #{path} doesn't implement the Access protocol!"
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
      Conform.Logger.error "the options #{mutually_exclusive_opts} are mutually exclusive"
    end

    # populate options
    options = case {app, key, schema} do
      {nil, nil, nil}  -> %{:type => :all}
      {_, _, true} -> %{:type => :schema}
      {^app, _, _} -> %{:type => :app, :app => app |> String.to_atom}
      {_, ^key, _} -> %{:type => :key, :key => key}
    end
    options = Map.put(options, :output, output)

    %{:env => env, :options => options}
  end
end
