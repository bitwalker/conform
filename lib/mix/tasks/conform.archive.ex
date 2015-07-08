defmodule Mix.Tasks.Conform.Archive do
  @moduledoc """
  Create an archive with the app.schema.ez name near the application's schema.
  An archive contains dependencies which are noted in the schema.
  """

  def run([schema_path]) do
    {:ok, curr_path} = File.cwd
    arch_dir = Path.dirname(schema_path)
    build_dir = case String.split(arch_dir, "/") |> List.last do
                  "files" ->
                    "#{curr_path}/_build/#{Mix.env}/lib"
                  _ ->
                    Path.dirname(arch_dir) <> "/_build/#{Mix.env}/lib"
    end

    schema = Conform.Schema.load!(schema_path)
    imports = Keyword.get(schema, :import, [])
    case imports do
      [] ->
        {:ok, "", []}
      _ ->
        File.cd(build_dir)
        # collect files for archive
        build_files = Enum.reduce(imports, [], fn(deps_app, acc) ->
          {:ok, files_list} = :file.list_dir("#{deps_app}/ebin")
          files_list = Enum.map(files_list, fn(filename) -> ("#{deps_app}/ebin/" <> "#{filename}") |> to_char_list end)
          :lists.append(acc, files_list)
        end)
        # create archive
        arch_name = List.first(String.split(Path.basename(schema_path), "."))
        {:ok, zip_path} = :zip.create(arch_dir <> "/#{arch_name}.schema.ez" |> to_char_list, build_files)
        File.cd(curr_path)
        {:ok, zip_path, build_files}
    end
  end
end
