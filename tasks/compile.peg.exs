defmodule Mix.Tasks.Compile.Peg do
  @moduledoc """
  Compiles Erlang Parsing Expression Grammars (PEGs).
  """
  @shortdoc "Compiles Erlang Parsing Expression Grammars (PEGs)."

  use Mix.Task

  @recursive     true
  @manifest      ".compile.peg"

  def run(_) do
    manifest = load_manifest!
    get_sources
    |> Enum.filter(&(compile?(&1, manifest)))
    |> Enum.map(&compile_peg/1)
    |> Enum.reduce([], &build_manifest/2)
    |> write_manifest!
  end

  def clean do
    get_sources |> Enum.map(&do_clean/1)
  end

  defp do_clean(source_path) do
    erl = erl_source_path(source_path)
    case File.exists?(erl) do
      true  -> File.rm!(erl)
      false -> :ok
    end
  end

  defp get_sources,
    do: Mix.Project.config[:erlc_paths] |> Mix.Utils.extract_files([:peg])

  defp compile?(source_path, manifest) do
    erl = source_path |> erl_source_path |> Path.expand
    peg = source_path |> Path.expand
    # If the compiled file doesn't exist, then compile
    case File.exists?(erl) do
      true ->
        # If the manifest doesn't contain an entry for the peg file, then compile
        case Map.get(manifest, source_path) do
          nil -> true
          last_compilation ->
            # Otherwise, compare the modified time of the peg file against the
            # last compilation time (in seconds) of that file, if modifications
            # have been made, then compile
            {:ok, %File.Stat{mtime: mtime}} = File.stat(peg)
            :calendar.datetime_to_gregorian_seconds(mtime) > last_compilation
        end
      false -> true
    end
  end

  defp compile_peg(source_path) do
    peg           = Path.expand(source_path)
    relative_path = Path.relative_to_cwd(source_path)
    info "Compiling #{relative_path}"
    case :neotoma.file('#{peg}') do
      :ok -> :ok
      {:error, reason} ->
        error "Failed to compile #{relative_path}: #{reason}"
        exit(:normal)
    end
    case File.stat(peg) do
      {:ok, %File.Stat{mtime: last_compilation}} ->
        {source_path, last_compilation |> :calendar.datetime_to_gregorian_seconds}
      {:error, :enoent} ->
        error "Cannot stat #{relative_path}!"
        exit(:normal)
    end
  end

  defp build_manifest({source_path, compilation_time}, manifest) do
    [<<source_path :: binary, ?\t, ?\t, "#{compilation_time}" :: binary>> | manifest]
  end

  defp write_manifest!([]), do: :ok
  defp write_manifest!(manifest) when is_list(manifest) do
    serialized  = manifest |> Enum.join(<<?\n>>)
    output_path = manifest_path
    case File.write!(output_path, serialized) do
      :ok              -> info "PEG manifest updated"
      {:error, reason} -> error "Unable to save PEG manifest: #{reason}"
    end
  end

  defp erl_source_path(source_path), do: String.replace(source_path, ".peg", ".erl")
  defp manifest_path, do: Mix.Project.app_path |> Path.join(@manifest) |> Path.expand

  defp load_manifest! do
    manifest = manifest_path
    case File.exists?(manifest_path) do
      true  ->
        # Create resource from manifest
        res = Stream.resource(
          fn -> File.open!(manifest) end,
          fn file ->
            case IO.read(file, :line) do
              data when is_binary(data) -> {[data], file}
              _ -> {:halt, file}
            end
          end,
          fn file -> File.close(file) end
        )
        # For each line in the manifest, split on \t, where the
        # first part is the source file path, and the second part
        # is the time at which that file was last compiled
        res
        |> Stream.map(fn line ->
          case line |> String.split(<<?\t, ?\t>>, [parts: 2, trim: true]) do
            [path, mtime] ->
              {mtime, _} = Integer.parse(mtime)
              {path, mtime}
            _ ->
              nil
          end
        end)
        |> Stream.filter(fn meta -> meta != nil end)
        |> Enum.into(%{})
      false ->
        %{}
    end
  end

  defp info(message),  do: print(message)
  defp error(message), do: print(message, IO.ANSI.red)
  defp print(message, color \\ nil) do
    has_colors? = IO.ANSI.enabled?
    cond do
      color == nil -> message
      has_colors?  -> color <> message <> IO.ANSI.reset
      true         -> message
    end |> IO.puts
  end

end