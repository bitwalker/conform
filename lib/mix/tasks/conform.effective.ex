defmodule Mix.Tasks.Conform.Effective do
  @moduledoc """
  Print the effective configuration for the current project, either
  in it's entirety, or for a specific app, or setting

  ## Examples

    # Print the entire effective configuration
    mix conform.effective

    # Print the effective configuration for an application
    mix conform.effective --app myapp

    # Print the effective configuration for a specific setting
    mix conform.effective --key myapp.key.subkey

    # Print the effective configuration for a specific environment
    mix conform.effective --env prod

  Usage of `--app` and `--key` are mutually exclusive, but `--env` can be
  provided for all three use cases.

  """
  @shortdoc "Print the effective configuration for the current project"

  use    Mix.Task
  import Conform.Utils

  @doc """
  Perform some actions within the context of a specific mix environment
  """
  defmacro with_env(env, do: body) do
    quote do
      old_env = Mix.env
      # Change env
      Mix.env(unquote(env))
      result = unquote(body)
      # Change back
      Mix.env(old_env)
      result
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
    app = Mix.Project.config |> Keyword.get(:app)
    # Load the base configuration from config.exs if it exists, and validate it
    # If config.exs doesn't exist, proceed if a .conf file exists, otherwise there
    # is no configuration to display
    config = if File.exists?("config/config.exs") do
      # Switch environments when reading the config
      contents = with_env args.env do
        Path.join([File.cwd!, "config", "config.exs"]) |> Mix.Config.read!
      end
      case Mix.Config.validate!(contents) do
        true  -> contents
        false ->
          error "The contents of config/config.exs are invalid!"
          exit(:normal)
      end
    else
      # Proceed with an empty config if a .conf is provided
      if File.exists?("config/#{app}.conf") do
        []
      else
        info "Your project contains no configuration."
        exit(:normal)
      end
    end
    # Read .conf and .schema.exs
    conf   = Path.join([File.cwd!, "config", "#{app}.conf"])       |> Conform.Parse.file
    schema = Path.join([File.cwd!, "config", "#{app}.schema.exs"]) |> Conform.Schema.load
    # Translate .conf -> config
    translated = Conform.Translate.to_config(conf, schema)
    # Merge the .conf configuration over configuration in config.exs
    effective = Mix.Config.merge(config, translated)
    # Print the configuration as requested
    case args.options.type do
      :all -> Conform.Config.print(effective)
      :app -> 
        case effective |> Keyword.get(args.options.app) do
          nil        -> notice "App not found!"
          app_config -> Conform.Config.print(app_config)
        end
      :key ->
        "#{args.options.key}: #{effective |> extract_key(args.options.key)}" |> IO.puts
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
    env = args |> Keyword.get(:env, "dev") |> String.to_atom
    app = args |> Keyword.get(:app)
    key = args |> Keyword.get(:key)
    # Determine options
    options = case {env, app, key} do
      {^env, nil, nil}  -> %{:type => :all}
      {^env, ^app, nil} -> %{:type => :app, :app => app |> String.to_atom}
      {^env, nil, ^key} -> %{:type => :key, :key => key}
      _ ->
        error "--app and --key cannot be provided at the same time"
        exit(:normal)
    end
    # Make sure env is a valid value
    unless env in [:test, :dev, :prod] do
      error "The value provided for --env is not a valid environment"
      exit(:normal)
    end
    %{:env => env, :options => options}
  end
end