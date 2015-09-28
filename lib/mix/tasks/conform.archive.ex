defmodule Mix.Tasks.Conform.Archive do
  @moduledoc """
  Create an archive with the app.schema.ez name near the application's schema.
  An archive contains dependencies which are noted in the schema.
  """

  def run([schema_path]) do
    curr_path  = File.cwd!
    schema_dir = Path.dirname(schema_path) |> Path.expand
    build_dir = case String.split(schema_dir, "/") |> List.last do
      "files" -> "#{curr_path}/_build/#{Mix.env}/lib"
      _       -> "#{Path.dirname(schema_dir)}/_build/#{Mix.env}/lib"
    end

    raw_schema = File.read!(schema_path) |> Conform.Schema.parse!
    imports = Keyword.get(raw_schema, :import)
    extends = Keyword.get(raw_schema, :extends)
    case {imports, extends} do
      {[], []} -> {:ok, "", []}
      {_, _}   ->
        # Make config dir in _build, move schema files there
        archiving = Enum.reduce(extends, [], fn app, acc ->
          app_path = Mix.Dep.children
                     |> Enum.filter(fn %Mix.Dep{app: app_name} -> app_name == app end)
                     |> Enum.map(fn %Mix.Dep{opts: opts} ->
                       Keyword.get(opts, :path, Keyword.get(opts, :dest))
                     end)
                     |> Enum.filter(fn nil -> false; _ -> true end)
                     |> Enum.map(fn path -> Path.expand(path) end)
          case app_path do
            nil -> []
            [app_path] ->
              src_path = Path.join([app_path, "config", "#{app}.schema.exs"])
              if File.exists?(src_path) do
                dest_path = Path.join(["#{app}", "config", "#{app}.schema.exs"])
                File.mkdir_p!(Path.join(build_dir, Path.dirname(dest_path)))
                File.cp!(src_path, Path.join(build_dir, dest_path))
                [String.to_char_list(dest_path) | acc]
              else
                []
              end
          end
        end)
        File.cd! build_dir
        # Add imported application BEAM files to archive
        archiving = Enum.reduce(imports, archiving, fn app, acc ->
          path  = Path.join("#{app}", "ebin")
          files = path
          |> File.ls!
          |> Enum.map(fn filename -> Path.join(path, filename) end)
          |> Enum.map(&String.to_char_list/1)
          files ++ acc
        end)
        # create archive
        [archive_name|_] = String.split(Path.basename(schema_path), ".")
        archive_path     = Path.join(schema_dir, "#{archive_name}.schema.ez")
        {:ok, zip_path}  = :zip.create('#{archive_path}', archiving)
        # Reset current directory
        File.cd! curr_path
        # Return the path to the archive and what was archived
        {:ok, zip_path, archiving}
    end
  end
end
