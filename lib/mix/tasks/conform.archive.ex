defmodule Mix.Tasks.Conform.Archive do
  @moduledoc """
  Create an archive with the app.schema.ez name near the application's schema.
  An archive contains dependencies which are noted in the schema.
  """

  def run([schema_path]) do
    Mix.Tasks.Loadpaths.run([])
    curr_path  = File.cwd!
    schema_dir = Path.dirname(schema_path) |> Path.expand
    build_dir = case String.split(schema_dir, "/") |> List.last do
      "files" -> "#{curr_path}/_build/#{Mix.env}/lib"
      _       -> "#{Path.dirname(schema_dir)}/_build/#{Mix.env}/lib"
    end

    raw_schema = File.read!(schema_path) |> Conform.Schema.parse!
    imports = Keyword.get(raw_schema, :import, [])
    extends = Keyword.get(raw_schema, :extends, [])
    case {imports, extends} do
      {[], []} -> {:ok, "", []}
      {_, _}   ->
        specified_deps = Mix.Dep.loaded(env: Mix.env)
        # collect deps which are specifed outside of deps,
        # like: [:name, path: "path_to_lib"]
        deps_paths = Enum.map(specified_deps, fn (dep) ->
          if dep.opts[:path] != nil do
            {Path.basename(dep.opts[:path]), dep.opts[:path]}
          else
            []
          end
        end) |> :lists.flatten
        # Make config dir in _build, move schema files there
        archiving = Enum.reduce(extends ++ deps_paths, [], fn app, acc ->
          {app, src_path} = case app do
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
            [String.to_char_list(dest_path) | acc]
          else
            []
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
