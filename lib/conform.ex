defmodule Conform do
  @moduledoc """
  Entry point for Conform escript
  """
  alias Conform.Logger

  defmodule Options do
    defstruct conf: "", schema: "", write_to: "", config: ""
  end

  def main(argv), do: argv |> parse_args |> process

  @doc """
  `argv` can be `-h` or `--help`, which returns `:help`.

  At a minimum, expects two arguments, `--conf foo.conf`, and `--schema foo.schema.exs`,
  and outputs the translated sys.config file.

  If `--filename <name>` is given, output is named `<name>`.

  If `--output-dir <path>` is given, output is saved to `<path>/<sys|name>.config`.

  If `--config <config>` is given, `<config>` is merged under the translated
  config prior to output. Use this to merge a default sys.config with the
  configuration generated from the source .conf file.

  If `--code-path <path>` is given, `<path>` will be appended to the code path.
  """
  def parse_args([]) do
    :help
  end

  def parse_args(argv) do
    parse = OptionParser.parse(argv, switches: [help: :boolean,      conf: :string,
                                                schema: :string,     filename: :string,
                                                output_dir: :string, config: :string,
                                                code_path: :string],
                                     aliases:  [h:    :help])
    case parse do
      {[help: true], _, _} -> :help
      {switches, _, _}     -> switches
      _                    -> :help
    end
  end

  # Process help
  defp process(:help) do
    IO.puts """
    Conform - Translate the provided .conf file to a .config file using the given schema
    -------
    usage: conform --conf foo.conf --schema foo.schema.exs [options]

    Options:
      --filename <name>:    Names the output file <name>.config
      --output-dir <path>:  Outputs the .config file to <path>/<sys|name>.config
      --config <config>:    Merges the translated configuration over the top of
                            <config> before output
      --code-path <path>:   Adds the given path to the current code path, accepts wildcards.
      -h | --help:          Prints this help
    """
    exit({:shutdown, 0})
  end

  # Convert switches to fully validated Options struct
  defp process(switches) when is_list(switches) do
    conf   = Keyword.get(switches, :conf, nil)
    schema = Keyword.get(switches, :schema, nil)
    case {conf, schema} do
      {nil, _} -> Logger.warn("--conf is required"); process(:help)
      {_, nil} -> Logger.warn("--schema is required"); process(:help)
      {^conf, ^schema} ->
        # Read in other options or their defaults
        filename = Keyword.get(switches, :filename, "sys.config")
        path     = Keyword.get(switches, :output_dir, File.cwd!) |> Path.join(filename)
        config   = Keyword.get(switches, :config, nil)
        case Keyword.get(switches, :code_path) do
          nil -> :ok
          path when is_binary(path) ->
            Path.wildcard(Path.expand(path))
            |> Enum.each(fn p -> :code.add_pathz('#{p}') end)
        end
        # Process options
        %Options{conf: conf, schema: schema, write_to: path, config: config } |> process
    end
  end

  defp process(%Options{} = options) do
    # Read .conf and .schema.exs
    final = case Conform.Conf.from_file(options.conf) do
      {:error, reason} when is_binary(reason) ->
        Logger.error "Failed to read .conf!\n#{reason}"
      {:error, reason} ->
        Logger.error "Failed to read .conf!\nError: #{inspect reason}"
      {:ok, conf} ->
        schema = Conform.Schema.load!(options.schema)
        # Read .config if exists
        case options.config do
          nil  ->
            Conform.Translate.to_config(schema, [], conf)
          path ->
            # Merge .config if exists and can be parsed
            case Conform.SysConfig.read(path) do
              {:ok, [config]} ->
                Conform.Translate.to_config(schema, config, conf)
              {:error, _} ->
                Logger.error """
                Unable to parse config at #{path}
                Check that the file exists and is in the correct format.
                """
            end
        end
    end
    # Write final .config to options.write_to
    case Conform.SysConfig.write(options.write_to, final) do
      :ok ->
        :ok
      {:error, reason} ->
        Logger.error "Unable to write configuration file #{options.write_to} with reason: #{reason}"
    end
    # Print success message
    Logger.success "Generated #{options.write_to |> Path.basename} in #{options.write_to |> Path.dirname}"
  end

end
