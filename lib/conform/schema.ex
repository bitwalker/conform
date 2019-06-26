defmodule Conform.Schema do
  @moduledoc """
  A schema is a keyword list which represents how to map, transform, and validate
  configuration values parsed from the .conf file. The following is an explanation of
  each key in the schema definition in order of appearance, and how to use them.

  ## Import

  A list of application names (as atoms), which represent apps to load modules from
  which you can then reference in your schema definition. This is how you import your
  own custom Validator/Transform modules, or general utility modules for use in
  validator/transform functions in the schema. For example, if you have an application
  `:foo` which contains a custom Transform module, you would add it to your schema like so:

  `[ import: [:foo], ..., transforms: ["myapp.some.setting": MyApp.SomeTransform]]`

  ## Extends

  A list of application names (as atoms), which contain schemas that you want to extend
  with this schema. By extending a schema, you effectively re-use definitions in the
  extended schema. You may also override definitions from the extended schema by redefining them
  in the extending schema. You use `:extends` like so:

  `[ extends: [:foo], ... ]`

  ## Mappings

  Mappings define how to interpret settings in the .conf when they are translated to
  runtime configuration. They also define how the .conf will be generated, things like
  documention, @see references, example values, etc.

  See the moduledoc for `Conform.Schema.Mapping` for more details.

  ## Transforms

  Transforms are custom functions which are executed to build the value which will be
  stored at the path defined by the key. Transforms have access to the current config
  state via the `Conform.Conf` module, and can use that to build complex configuration
  from a combination of other config values.

  See the moduledoc for `Conform.Schema.Transform` for more details and examples.

  ## Validators

  Validators are simple functions which take two arguments, the value to be validated,
  and arguments provided to the validator (used only by custom validators). A validator
  checks the value, and returns `:ok` if it is valid, `{:warn, message}` if it is valid,
  but should be brought to the users attention, or `{:error, message}` if it is invalid.

  See the moduledoc for `Conform.Schema.Validator` for more details and examples.
  """
  alias __MODULE__
  @type schema :: __MODULE__

  defstruct import: [],
            extends: [],
            mappings: [],
            transforms: [],
            validators: []

  defmodule SchemaError do
    @moduledoc """
    This exception reflects an issue with the schema
    """
    defexception message: "Invalid schema. Should be a keyword list with at least the :mappings key defined"
  end

  @doc """
  Get the current app's schema path
  """
  @spec schema_path() :: binary
  def schema_path(),    do: Mix.Project.config |> Keyword.get(:app) |> schema_path
  def schema_path(app) do
    conf_dir = Conform.Utils.src_conf_dir(app)
    Path.join([conf_dir, schema_filename(app)])
  end

  @doc """
  get the current app's schema filename
  """
  def schema_filename(app), do: "#{app}.schema.exs"

  @doc """
  Parses the schema at the provided path as quoted terms.
  Returns {:ok, quoted} | {:error, {line, error, details}}
  """
  @spec parse(String.t) :: {:ok, term} | {:error, {integer, binary, binary}}
  def parse(binary) when is_binary(binary) do
    res = case Code.string_to_quoted(binary) do
      {:ok, {:__block__, _, [_, quoted]}} ->
        {:ok, quoted}
      {:ok, quoted} ->
        {:ok, quoted}
      {:error, _} = err -> err
    end
    case res do
      {:ok, quoted} ->
        case Code.eval_quoted(quoted, file: "nofile", line: 0) do
          {schema, _} when is_list(schema) ->
            {:ok, schema}
          {other, _} ->
            {:error, {0, "Invalid schema: ", "Expected schema, but got #{inspect other}"}}
        end
      {:error, _} = err ->
        err
    end
  rescue
    e in [CompileError] ->
      {:error, {0, "Invalid schema: ", Exception.message(e)}}
  end

  @doc """
  Parses the schema at the provided path as quoted terms.
  Returns the quoted terms or raises SchemaError on failure.
  """
  @spec parse!(String.t) :: term | no_return
  def parse!(binary) when is_binary(binary) do
    case parse(binary) do
      {:ok, quoted} -> quoted
      {:error, {line, error, details}} ->
        raise SchemaError, message: "Invalid schema at line #{line}: #{error}#{details}."
    end
  end

  @doc """
  Load a schema from the provided path. Throws on error.
  Used for schema evaluation only.
  """
  @spec load!(binary | atom) :: schema
  def load!(path) when is_binary(path) do
    if File.exists?(path) do
      path |> File.read! |> parse! |> from(path)
    else
      raise SchemaError, message: "Schema at #{path} doesn't exist!"
    end
  end
  def load!(name) when is_atom(name), do: name |> schema_path |> load!

  @doc """
  Loads a schema from the provided path.
  Returns {:ok, schema} | {:error, message}
  """
  @spec load(binary | atom) :: {:ok, schema} | {:error, term}
  def load(path) do
    try do
      {:ok, load!(path)}
    rescue
      err in SchemaError -> {:error, err.message}
    end
  end

  # Ignore the documentation block if one is present
  defp from(quoted, path) when is_list(quoted) do
    # Load imports from archive if present
    archive_path = String.replace(path, ".exs", ".ez")
    load_archive(archive_path)
    # Build schema
    schema = %Schema{}
    # Get and validate imports
    schema = case Keyword.get(quoted, :import) do
      nil -> schema
      imports when is_list(imports) ->
        imports = Enum.map(imports, fn i ->
          case valid_import?(i) do
            true  -> i
            false ->
              Conform.Logger.warn "Schema imports #{i}, but #{i} could not be loaded."
              nil
          end
        end) |> Enum.filter(fn nil -> false; _ -> true end)
        %{schema | :import => imports}
    end
    # Get and validate mappings
    schema = case Keyword.get(quoted, :mappings) do
      nil -> raise SchemaError, message: "Schema must contain at least one mapping!"
      mappings when is_list(mappings) ->
        %{schema | :mappings => Enum.map(mappings, &Conform.Schema.Mapping.from_quoted/1)}
    end
    # Get and validate transforms
    schema = case Keyword.get(quoted, :transforms) do
      nil -> schema
      transforms when is_list(transforms) ->
        user_defined = Enum.map(transforms, &Conform.Schema.Transform.from_quoted/1)
        %{schema | :transforms => user_defined}
    end
    # Get and validate validators
    global_validators = Conform.Schema.Validator.load
    schema = case Keyword.get(quoted, :validators) do
      nil -> %{schema | :validators => global_validators}
      validators when is_list(validators) ->
        user_defined = Enum.map(validators, &Conform.Schema.Validator.from_quoted/1)
        %{schema | :validators => user_defined ++ global_validators}
    end
    # Determine if we are extending any schemas in
    # dependencies of this application. `extends` should be a list of application names
    # as atoms. Given an application, we will fetch it's schema, load it, and merge it
    # on to our base schema. Definitions in this schema will then override those which are
    # present in the schemas being extended.
    case Keyword.get(quoted, :extends) do
      nil -> schema
      extends when is_list(extends) ->
        # Load schemas
        schemas = Enum.map(extends, fn
          e when is_atom(e) ->
            case get_extends_schema(e, path) do
              nil ->
                Conform.Logger.warn "Schema extends #{e}, but the schema for #{e} was not found."
                nil
              {schema_path, contents} ->
                contents |> parse! |> from(schema_path)
            end
          e ->
            Conform.Logger.warn "Invalid extends value: #{e}. Only application names as atoms are permitted."
            nil
        end) |> Enum.filter(fn nil -> false; _ -> true end)
        # Merge them onto the base schema in the order provided
        Enum.reduce(schemas, schema, fn s, acc ->
          s = Map.drop(s, [:extends])
          Map.merge(acc, s, fn
            _, [], [] ->
              []
            _, v1, v2 ->
              cond do
                Keyword.keyword?(v1) && Keyword.keyword?(v2) ->
                  Keyword.merge(v1, v2) |> Enum.map(fn _, v -> put_in(v, [:persist], false) end)
                is_list(v1) && is_list(v2) ->
                  v1 |> Enum.concat(v2) |> Enum.uniq
                true ->
                  v2
              end
          end)
        end)
    end
  end

  @doc """
  Load the schemas for all dependencies of the current project,
  and merge them into a single schema. Schemas are returned in
  their quoted form.
  """
  @spec coalesce() :: schema
  def coalesce do
    # Get schemas from all dependencies
    # Merge schemas for all deps
    Mix.Dep.loaded([])
    |> Enum.map(fn %Mix.Dep{app: app, opts: opts} ->
         Mix.Project.in_project(app, opts[:dest], opts, fn _ -> load!(app) end)
       end)
    |> coalesce()
  end

  @doc """
  Given a collection of schemas, merge them into a single schema
  """
  @spec coalesce([schema]) :: schema
  def coalesce(schemas) do
    Enum.reduce(schemas, empty(), &merge/2)
  end

  @doc """
  Merges two schemas. Conflicts are resolved by taking the value from `y`.
  Expects the schema to be provided in it's quoted form.
  """
  @spec merge(schema, schema) :: schema
  def merge(%Schema{} = x, %Schema{} = y) do
    Map.merge(x, y, fn key, v1, v2 ->

      case Keyword.keyword?(v1) && Keyword.keyword?(v2) do
        true  -> Keyword.merge(v1, v2)
        false ->
          case key == :__struct__ do
            true -> v2
            false -> v1 |> Enum.concat(v2) |> Enum.uniq
          end
      end
    end)
  end

  @doc """
  Saves a schema to the provided path
  """
  @spec write(schema, binary) :: :ok | {:error, term}
  def write(schema, path) do
    File.write!(path, stringify(schema))
  end

  @doc """
  Converts a schema in it's quoted form and writes it to
  the provided path
  """
  @spec write_quoted(schema, binary) :: :ok | {:error, term}
  def write_quoted(schema, path) do
    File.write!(path, stringify(schema))
  end

  @doc """
  Converts a schema to a prettified string. Expects the schema
  to be in it's quoted form.
  """
  @spec stringify([term]) :: binary
  def stringify(schema, with_moduledoc \\ true) do
    string = if schema == Conform.Schema.empty do
      schema
      |> to_list
      |> Inspect.Algebra.to_doc(%Inspect.Opts{pretty: true})
      |> Inspect.Algebra.format(10)
      |> Enum.join
    else
      schema
      |> to_list
      |> Conform.Utils.Code.stringify
    end
    case with_moduledoc do
      true ->
        "@moduledoc \"\"\"\n" <> @moduledoc <> "\"\"\"\n" <> string
      false ->
        string
    end
  end

  defp to_list(%Schema{} = schema) do
    schema |> Map.to_list |> Keyword.delete(:__struct__) |> Enum.map(&to_list/1)
  end
  defp to_list({k, v}) when is_list(v) do
    {k, Enum.map(Enum.sort(v, &do_sort/2), &to_list/1)}
  end
  defp to_list(%Conform.Schema.Validator{name: nil, definition: nil, validator: v}), do: v
  defp to_list(%Conform.Schema.Validator{name: name, definition: v}), do: {String.to_atom(name), v}
  defp to_list(%Conform.Schema.Transform{path: path, definition: nil, transform: t}), do: {String.to_atom(path), t}
  defp to_list(%Conform.Schema.Transform{path: path, definition: t}), do: {String.to_atom(path), t}
  defp to_list(%Conform.Schema.Mapping{name: name} = mapping) do
    props = mapping
            |> Map.to_list
            |> Keyword.delete(:__struct__)
            |> Keyword.delete(:name)
            |> Keyword.delete(:persist)
            |> Enum.filter(fn
              {_, ignore} when ignore in [nil, "", []] -> false
              _ -> true
            end)
    {String.to_atom(name), props}
  end
  defp to_list(v) when is_map(v) do
    v |> Map.to_list |> Keyword.delete(:__struct__)
  end

  defp do_sort(m1, m2) do
    key(m1) <= key(m2)
  end

  defp key(%Conform.Schema.Mapping{name: name}), do: name
  defp key(%Conform.Schema.Validator{name: name}), do: name
  defp key(k), do: k

  @doc """
  Convert standard configuration to quoted schema format
  """
  @spec from_config([] | [{atom, term}]) :: [{atom, term}]
  def from_config([]), do: empty()
  def from_config(config) when is_list(config) do
    to_schema(config)
  end

  def empty, do: %Schema{}

  defp to_schema([]),     do: %Schema{}
  defp to_schema(config), do: to_schema(Macro.escape(config), %Schema{})
  defp to_schema([], schema), do: schema
  defp to_schema([{app, settings} | config], schema) do
    mappings = settings
    |> Enum.map(fn {k, v} -> to_mapping("#{app}", k, v) end)
    |> List.flatten
    to_schema(config, %{schema | :mappings => schema.mappings ++ mappings})
  end

  defp to_mapping(key, setting, value) do
    case Keyword.keyword?(value) do
      true ->
        for {k, v} <- value, into: [] do
          to_mapping("#{key}.#{setting}", k, v)
        end
      false ->
        {val, _} = Code.eval_quoted(value)
        datatype     = extract_datatype(val)
        setting_name = "#{key}.#{setting}"
        Conform.Schema.Mapping.from_quoted({:"#{setting_name}", [
          doc:     "Provide documentation for #{setting_name} here.",
          to:       setting_name,
          datatype: datatype,
          default:  convert_to_datatype(datatype, val)
        ]})
    end
  end

  def extract_datatype(v) when is_atom(v),    do: :atom
  def extract_datatype(v) when is_binary(v),  do: :binary
  def extract_datatype(v) when is_boolean(v), do: :boolean
  def extract_datatype(v) when is_integer(v), do: :integer
  def extract_datatype(v) when is_float(v),   do: :float
  # First check if the list value type is a charlist, otherwise
  # build up a list of subtypes the list contains
  def extract_datatype([_h|_rest]=v) do
    case :io_lib.printable_unicode_list(v) do
      true  -> :charlist
      false ->
        subtypes = v
        |> Enum.map(&extract_datatype/1)
        |> Enum.uniq
        case subtypes do
          [list_type] -> [list: list_type]
          list_types when is_list(list_types) -> [list: list_types]
          list_type -> [list: list_type]
        end
    end
  end
  # Short cut for keyword lists
  def extract_datatype({k, v}), do: {extract_datatype(k), extract_datatype(v)}
  def extract_datatype(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list
    |> Enum.map(&extract_datatype/1)
    |> List.to_tuple
  end
  def extract_datatype(_), do: :binary

  defp convert_to_datatype(:binary, v) when is_binary(v),     do: v
  defp convert_to_datatype(:binary, v) when not is_binary(v), do: nil
  defp convert_to_datatype(_, v), do: v

  defp valid_import?(i) when is_atom(i) do
    case :code.lib_dir(i) do
      {:error, _} -> false
      path when is_list(path) -> true
    end
  end
  defp valid_import?(_), do: false

  defp get_extends_schema(app_name, src_schema_path) do
    # Attempt loading from deps if Mix is available
    schema_path = try do
      paths = Mix.Dep.loaded(env: Mix.env)
              |> Enum.filter(fn %Mix.Dep{app: app} -> app == app_name end)
              |> Enum.map(fn %Mix.Dep{opts: opts} ->
                Keyword.get(opts, :dest, Keyword.get(opts, :path))
              end)
              |> Enum.filter(fn nil -> false; _ -> true end)
      case paths do
        []         -> nil
        [app_path] -> Path.join([app_path, "config", "#{app_name}.schema.exs"])
      end
    catch
      _,_ -> nil
    rescue
      _ -> nil
    end
    # Next try locating by application
    schema_path = case schema_path do
      nil ->
        case :code.lib_dir(app_name) do
          {:error, _} -> nil
          path when is_list(path) ->
            path = List.to_string(path)
            case File.exists?(path <> ".ez") do
              true  -> Path.join([path <> ".ez", "#{app_name}", "config", "#{app_name}.schema.exs"])
              false -> Path.join([path, "config", "#{app_name}.schema.exs"])
            end
        end
      path when is_binary(path) ->
        path
    end
    schema_path = case schema_path == nil || File.exists?(schema_path) == false do
      true ->
        # If that fails, try loading from archive, if present
        archive_path = String.replace(src_schema_path, ".exs", ".ez")
        case File.exists?(archive_path) do
          false -> nil
          true  ->
            case :erl_prim_loader.list_dir('#{archive_path}') do
              :error -> nil
              {:ok, apps} ->
                case '#{app_name}' in apps do
                  true  -> Path.join([archive_path, "#{app_name}", "config", "#{app_name}.schema.exs"])
                  false -> nil
                end
            end
        end
      _ -> schema_path
    end
    case schema_path do
      nil -> nil
      schema_path when is_binary(schema_path) ->
        case File.exists?(schema_path) do
          true  -> {schema_path, File.read!(schema_path)}
          false ->
            case :erl_prim_loader.get_file('#{schema_path}') do
              :error             -> nil
              {:ok, contents, _} -> {schema_path, contents}
            end
        end
    end
  end

  defp load_archive(archive_path) do
    case File.exists?(archive_path) do
      true ->
        {:ok, [_ | zip_files]} = :zip.list_dir('#{archive_path}')
        apps = Enum.map(zip_files, fn {:zip_file, path, _, _, _, _} ->
          path = to_string(path)
          case :filename.extension(path) == ".app" do
            true  -> Path.dirname(path)
            false -> []
          end
        end) |> List.flatten

        Enum.each(apps, fn(app) ->
          path = Path.join(archive_path, app) |> Path.expand
          Code.prepend_path(path)
        end)
      false ->
        :ok
    end
  end
end
