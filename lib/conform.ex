defmodule Conform do
  @moduledoc """
  Entry point for Conform escript
  """

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
  """
  def parse_args([]) do
    :help
  end

  def parse_args(argv) do
    parse = OptionParser.parse(argv, switches: [help: :boolean,      conf: :string,
                                                schema: :string,     filename: :string,
                                                output_dir: :string, config: :string],
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
      -h | --help:          Prints this help
    """
    System.halt(0)
  end

  # Convert switches to fully validated Options struct
  defp process(switches) when is_list(switches) do
    conf   = Keyword.get(switches, :conf, nil)
    schema = Keyword.get(switches, :schema, nil)
    case {conf, schema} do
      {nil, _} -> error("--conf is required"); process(:help)
      {_, nil} -> error("--schema is required"); process(:help)
      {^conf, ^schema} ->
        # Read in other options or their defaults
        filename = Keyword.get(switches, :filename, "sys.config")
        path     = Keyword.get(switches, :output_dir, File.cwd!) |> Path.join(filename)
        config   = Keyword.get(switches, :config, nil)
        # Process options
        %Options{conf: conf, schema: schema, write_to: path, config: config } |> process
    end
  end

  defp process(%Options{} = options) do
    # Read .conf and .schema.exs
    final = case Conform.Parse.file(options.conf) do
      {:error, reason} ->
        error reason
        exit(:fatal)
      {:ok, conf} ->
        schema = options.schema |> Conform.Schema.load! |> Dict.delete(:import)
        arch_name = List.first(String.split(Path.basename(options.schema), ".")) <> ".schema.ez"
        # load all imports from archive
        load_imports(Path.dirname(options.schema) <> "/" <> arch_name)
        # Read .config if exists
        case options.config do
          nil  ->
            Conform.Translate.to_config([], conf, schema)
          path ->
            # Merge .config if exists and can be parsed
            case Conform.Config.read(path) do
              {:ok, [config]} ->
                translated = Conform.Translate.to_config(config, conf, schema)
                Conform.Config.merge(config, translated)
              {:error, _} ->
                error """
                Unable to parse config at #{path}
                Check that the file exists and is in the correct format.
                """
                exit(:fatal)
            end
        end
    end
    # Write final .config to options.write_to
    case Conform.Config.write(options.write_to, final) do
      :ok ->
        :ok
      {:error, reason} ->
        error """
        Unable to write configuration file #{options.write_to} with reason: #{reason}
        """
        exit(:fatal)
    end
    # Print success message
    success "Generated #{options.write_to |> Path.basename} in #{options.write_to |> Path.dirname}"
  end

  defp error(message) do
    IO.ANSI.red <> message <> IO.ANSI.reset |> IO.puts
  end
  defp success(message) do
    IO.ANSI.green <> message <> IO.ANSI.reset |> IO.puts
  end

  defp load_imports(arch_path) do
    case File.exists?(arch_path) do
      true ->
        {:ok, [_ | zip_files]} = :zip.list_dir(arch_path |> to_char_list)
        apps = Enum.map(zip_files, fn({:zip_file, path, _, _, _, _}) ->
          path = to_string(path)
          case :filename.extension(path) == ".app" do
            true ->
              [deps_app_path, _] = String.split(path, "ebin")
              Path.basename(deps_app_path)
            false ->
              []
          end
        end) |> :lists.flatten

        Enum.each(apps, fn(app) ->
          Code.append_path(to_string(arch_path) <> "/" <> app <> "/ebin")
        end)
      false ->
        :ok
    end
  end
end
