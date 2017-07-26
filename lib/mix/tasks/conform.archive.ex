defmodule Mix.Tasks.Conform.Archive do
  @moduledoc """
  Create an archive with the app.schema.ez name near the application's schema.
  An archive contains dependencies which are noted in the schema.
  """

  def run([schema_path]) do
    Mix.Tasks.Loadpaths.run([])
    curr_path  = File.cwd!
    schema_dir = Path.dirname(schema_path) |> Path.expand
    [release_name|_] = String.split(Path.basename(schema_path), ".")
    build_dir =
      case String.split(schema_dir, "/") |> List.last do
        "files" -> "#{curr_path}/_build/#{Mix.env}/lib"
        _       -> "#{Path.dirname(schema_dir)}/_build/#{Mix.env}/lib"
      end

    raw_schema = File.read!(schema_path) |> Conform.Schema.parse!
    imports = Keyword.get(raw_schema, :import, [])
    extends = Keyword.get(raw_schema, :extends, [])
    case {imports, extends} do
      {[], []} ->
        {:ok, "", []}
      {_, _}   ->
        specified_deps = Mix.Dep.loaded(env: Mix.env)
        # collect deps which are specifed outside of deps,
        # like: [:name, path: "path_to_lib"]
        deps_paths =
          specified_deps
          |> Enum.reject(fn %Mix.Dep{opts: opts} -> is_nil(opts[:path]) end)
          |> Enum.map(fn %Mix.Dep{opts: opts} -> {Path.basename(opts[:path]), opts[:path]} end)
        # Make config dir in _build, move schema files there
        archiving =
          extends
          |> Enum.concat(deps_paths)
          |> Enum.reduce([], fn app, acc ->
            {app, src_path} =
              case app do
                app_name when is_atom(app_name) ->
                  app_path = Path.join([curr_path, "deps", "#{app_name}"])
                  {app_name, Path.join([app_path, "config", "#{app_name}.schema.exs"])}
                {app_name, path_to_app} ->
                  {app_name, Path.join([curr_path, path_to_app, "config", "#{app_name}.schema.exs"])}
              end
            if File.exists?(src_path) do
              dest_path = Path.join(["#{app}", "config", "#{app}.schema.exs"])
              File.mkdir_p!(Path.join(build_dir, Path.dirname(dest_path)))
              File.cp!(src_path, Path.join(build_dir, dest_path))
              [String.to_charlist(dest_path) | acc]
            else
              acc
            end
          end)

        File.cd!(build_dir)

        # Add imported application BEAM files to archive
        archiving =
          Enum.reduce(imports, archiving, fn app, acc ->
            path = Path.join("#{app}", "ebin")
            path
            |> File.ls!
            |> Enum.map(fn filename -> Path.join(path, filename) end)
            |> Enum.map(&String.to_charlist/1)
            |> Enum.concat(acc)
          end)
        # create archive
        archive_path = Path.join(schema_dir, "#{release_name}.schema.ez")
        {:ok, zip_path} = :zip.create('#{archive_path}', archiving)
        # Reset current directory
        File.cd!(curr_path)
        # Return the path to the archive and what was archived
        {:ok, zip_path, archiving}
    end
  end
end
