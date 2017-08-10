defmodule Conform.Translate do
  @moduledoc """
  This module is responsible for translating either from .conf -> .config or
  from .schema.exs -> .conf
  """
  alias Conform.Schema
  alias Conform.Schema.Mapping
  alias Conform.Schema.Transform
  import Conform.Utils, only: [merge: 2]

  @type table_identifier :: non_neg_integer() | atom()

  defmodule TranslateError do
    @moduledoc """
    This exception reflects an issue with the translation process
    """
    defexception message: "Translation failed!"
  end

  @doc """
  Translate the provided schema to it's default .conf representation
  """
  @spec to_conf([{atom, term}]) :: binary
  def to_conf(%Schema{mappings: mappings}) do
    # Filter out hidden settings
    mappings = Enum.filter(mappings, fn %Mapping{hidden: false} -> true; _ -> false end)
    # Build conf string
    Enum.reduce mappings, "", fn %Mapping{name: key} = mapping, result ->
      # If the datatype of this mapping is an enum,
      # write out the allowed values
      datatype = mapping.datatype || :binary
      doc = mapping.doc || ""
      commented? = mapping.commented == true
      {custom?, mod, args} = is_custom_type?(datatype)
      comments = cond do
        custom? ->
          case {doc, mod.to_doc(args)} do
            {doc, false} -> to_comment(doc)
            {"", doc}    -> to_comment(doc)
            {doc, extra} -> to_comment("#{doc}\n#{extra}")
          end
        true ->
          to_comment(doc)
      end
      result = case datatype do
        [enum: values] ->
          allowed = "# Allowed values: #{Enum.join(values, ", ")}\n"
          <<result::binary, comments::binary, ?\n, allowed::binary>>
        _ ->
          <<result::binary, comments::binary, ?\n>>
      end
      result = case mapping.env_var do
                 nil -> result
                 var ->
                   default_msg = "# If not set, will use value of #{var} environment variable"
                   <<result::binary, default_msg::binary, ?\n>>
               end
      key = quote_key(key)
      case mapping.default do
        nil ->
          <<result::binary, "# #{key} = \n\n">>
        default when commented? ->
          <<result::binary, "# #{key} = #{write_datatype(datatype, default, key)}\n\n">>
        default ->
          <<result::binary, "#{key} = #{write_datatype(datatype, default, key)}\n\n">>
      end
    end
  end

  defp quote_key(key) do
    key
    |> String.split(".")
    |> Enum.map(fn part ->
      case String.contains?(part, " ") do
        true  -> "\"#{part}\""
        false -> part
      end
    end)
    |> Enum.join(".")
  end

  @doc """
  Translate the provided .conf to it's .config representation using the provided schema.
  """
  @spec to_config(%Conform.Schema{}, [{term, term}] | [], table_identifier) :: term
  def to_config(%Schema{} = schema, config, conf_table_id) do
    conf = apply_schema(conf_table_id, schema)
    config
    |> merge(conf)   # Merge the conf over config.exs/sys.config terms
  end

  defp apply_schema(conf_table_id, %Schema{} = schema) do
    try do
      # Convert mappings/transforms to same key format
      mappings = schema.mappings
                 |> Enum.map(fn %Mapping{name: key, to: to} = mapping ->
                     new_key = Conform.Conf.get_key_path(key)
                     case to do
                       nil -> %{mapping | :name => new_key}
                       to  -> %{mapping | :name => new_key, :to => Conform.Conf.get_key_path(to)}
                     end
                   end)
                 # Sort by key length to ensure that mappings are processed depth-first
                 |> Enum.sort_by(fn %Mapping{name: key} -> Enum.count(key) end, fn x, y -> x >= y end)
      transforms = schema.transforms
      |> Enum.map(fn %Transform{path: key} = transform ->
           %{transform | :path => Conform.Conf.get_key_path(key)}
         end)
      # Apply datatype conversions
      convert_types(mappings, conf_table_id)
      # Build/map complex types
      convert_complex_types(mappings, conf_table_id, mappings)
      # Map simple types
      apply_mappings(mappings, conf_table_id)
      # Apply translations to aggregated values
      apply_transforms(transforms, conf_table_id)
      # Fetch config from ETS, convert to config tree
      :ets.tab2list(conf_table_id) |> Conform.Utils.results_to_tree
    catch
      err ->
        Conform.Logger.error("Error thrown when constructing configuration: #{Macro.to_string(err)}")
    end
  end

  defp convert_types([], _), do: true
  defp convert_types([%Mapping{name: key} = mapping | rest], table) do
    # Get conf item
    case Conform.Conf.get(table, key) do
      # No matches
      [] ->
        convert_types(rest, table)
      # Matches requiring conversion
      results when is_list(results) ->
        datatype = mapping.datatype || :binary
        default  = case mapping.env_var do
                     nil -> mapping.default
                     var when is_binary(var) ->
                       case System.get_env(var) do
                         nil -> mapping.default
                         val -> parse_datatype(datatype, [val], mapping)
                       end
                   end
        for {conf_key, value} <- results, not datatype in [:complex, [list: :complex]] do
          parsed = case value do
            nil -> default
            _   -> parse_datatype(datatype, List.wrap(value), mapping)
          end
          :ets.insert(table, {conf_key, parsed})
        end
        convert_types(rest, table)
    end
  end

  defp apply_mappings([], _), do: true
  defp apply_mappings([%Mapping{name: key, datatype: datatype} = mapping | rest], table) do
    wildcard? = is_wildcard?(key)
    to_key    = mapping.to || key
    case Conform.Conf.wildcard_get(table, key) do
      # For wildcard keys, do not set defaults unless it's a complex type, and it's
      # destination key has not yet been set to any meaningful value
      [] when wildcard? and datatype in [:complex, [list: :complex]] ->
        case Conform.Conf.get(table, mapping.to) do
          [{_, nil}] ->
            :ets.insert(table, {mapping.to, mapping.default})
          _other ->
            :ok
        end
      # We cannot set default values for wildcard keys
      [] when wildcard? ->
        :ok
      # No matches, use default value
      [] ->
        default = case mapping.env_var do
          nil -> mapping.default
          var ->
            case System.get_env(var) do
              nil ->
                case mapping.default do
                  nil -> raise missing_env_var(var, key)
                  default -> default
                end
              val -> parse_datatype(datatype, [val], mapping)
            end
        end
        :ets.insert(table, {to_key, default})
      # A single value to be mapped
      [{from_key, vars, value}] ->
        :ets.delete(table, from_key)
        to_key = apply_key_variables(to_key, vars)
        :ets.insert(table, {to_key, value})
      # A list of results that is going to be accumulated into a list of values mapped as one
      results when is_list(results) ->
        # Delete selected results, and perform mapping
        for {selected_key, vars, value} <- results do
          :ets.delete(table, selected_key)
          to_key = apply_key_variables(to_key, vars)
          :ets.insert(table, {to_key, value})
        end
    end
    apply_mappings(rest, table)
  end

  defp is_wildcard?([]),             do: false
  defp is_wildcard?(['*'|_rest]),    do: true
  defp is_wildcard?([[?$|_]|_rest]), do: true
  defp is_wildcard?([_|rest]),       do: is_wildcard?(rest)

  defp convert_complex_types([], _, _), do: true
  defp convert_complex_types([%Mapping{name: key, datatype: complex} = mapping | rest], table, mappings)
    when complex in [:complex, [list: :complex]] do
      to_key = mapping.to || key
      # Build complex type
      {selected, complex} = construct_complex_type(mapping, table, mappings)
      # Iterate over the selected keys, deleting them from the table
      for {selected_key, _} <- selected do
        :ets.delete(table, selected_key)
      end
      # Insert the mapped value
      :ets.insert(table, {to_key, complex})
      # Move to next mapping
      convert_complex_types(rest, table, mappings)
  end
  defp convert_complex_types([%Mapping{} | rest], table, mappings) do
    convert_complex_types(rest, table, mappings)
  end

  defp starts_with?([], _b),       do: false
  defp starts_with?(_a, []),       do: true
  defp starts_with?([h|a], [h|b]), do: starts_with?(a, b)
  defp starts_with?(_, _),         do: false

  defp strip_prefix(['*'|name], []),      do: name
  defp strip_prefix([[?$|_] | name], []), do: name
  defp strip_prefix(name, []),            do: name
  defp strip_prefix([part|name], [part|prefix]), do: strip_prefix(name, prefix)

  defp construct_complex_type(%Mapping{name: key}, table, mappings) do
    # Get all records which match the current map_key + children
    selected = Conform.Conf.fuzzy_get(table, key)
    # Apply default values to any missing keys of the complex type
    prefix = Enum.take_while(key, fn '*' -> false; _ -> true end)
    child_mappings = mappings
    |> Enum.filter(fn %Mapping{name: name} -> starts_with?(name, prefix) end)
    |> Enum.map(fn %Mapping{name: name, default: default} = mapping ->
      stripped = strip_prefix(name, prefix)
      case mapping.env_var do
        nil ->
          {stripped, default}
        var ->
          case System.get_env(var) do
            nil ->
              case default do
                nil -> raise missing_env_var(var, key)
                default -> {stripped, default}
              end
            val -> {stripped, parse_datatype(mapping.datatype, [val], mapping)}
          end
      end
    end)
    children = Enum.map(selected, fn {name, _} -> List.first(strip_prefix(name, prefix)) end) |> Enum.uniq
    selected = Enum.reduce(children, selected, fn child, acc ->
      defaults = Enum.reduce(child_mappings, [], fn
        {[], _default}, acc2 ->
          acc2
        {subkey, default}, acc2 ->
          child_key = prefix ++ [child | subkey]
          case Enum.find(acc, fn {^child_key, _} -> true; _ -> false end) do
            nil ->
              [{child_key, default} | acc2]
            _ ->
              acc2
          end
      end)
      case defaults do
        [] -> acc
        _  -> defaults ++ acc
      end
    end)
    # Generate a recursive keywordlist structure representing the type
    complex  = Conform.Utils.results_to_tree(selected, key)
    # We return the selected items as well as the constructed type so that
    # we can perform additional actions against those results (such as deletion)
    # if desired.
    {selected, complex}
  end

  defp apply_transforms([], _table), do: true
  defp apply_transforms([%Transform{path: key, transform: transform} | rest], table) do
    transformed = case transform do
      t when is_atom(t) ->
        t.transform(table)
      t when is_function(t, 1) ->
        t.(table)
      _ ->
        problem_key = Enum.map(key, &List.to_string/1) |> Enum.join(".")
        Conform.Logger.error("Invalid transform for #{problem_key}. Must be a function of arity 1")
    end
    :ets.insert(table, {key, transformed})
    apply_transforms(rest, table)
  end

  # Add a .conf-style comment to the given line
  defp add_comment(line), do: "# #{line}"

  # Parse the provided value as a value of the given datatype
  defp parse_datatype([list: types], values, %Mapping{name: name} = mapping) when is_list(types) and length(types) > 1 do
    Enum.map(values, fn element ->
      res = Enum.reduce(types, element, fn
        _type, {:ok, _} = result ->
          result
        type, element ->
          try do
            case parse_datatype_single(type, element, mapping) do
              nil -> element
              parsed -> {:ok, parsed}
            end
          rescue
            _ ->
              element
          end
      end)
      case res do
        {:ok, parsed} -> parsed
        _other ->
          raise TranslateError, message: "Invalid format for #{stringify_key(name)}: Expected one of: #{inspect types}"
      end
    end)
  end
  defp parse_datatype([list: type], values, %Mapping{} = mapping) do
    Enum.map(values, &parse_datatype_single(type, &1, mapping))
  end
  defp parse_datatype(type, [value], %Mapping{} = mapping) do
    parse_datatype_single(type, value, mapping)
  end
  defp parse_datatype(type, value, %Mapping{name: name}) do
    raise TranslateError, "Invalid value for #{stringify_key(name)}: Expected value of type `#{inspect type}`, got #{inspect value}"
  end

  defp parse_datatype_single(:atom, value, _mapping),     do: String.to_atom("#{value}")
  defp parse_datatype_single(:binary, value, _mapping),   do: sanitize(value)
  defp parse_datatype_single(:charlist, value, _mapping), do: '#{sanitize(value)}'
  defp parse_datatype_single(:boolean, value, %Mapping{name: name}) do
    try do
      case String.to_existing_atom("#{value}") do
        true  -> true
        false -> false
        _     -> raise TranslateError, message: "Invalid boolean value for #{stringify_key(name)}."
      end
    rescue
      ArgumentError ->
        raise TranslateError, message: "Invalid boolean value for #{stringify_key(name)}."
    end
  end
  defp parse_datatype_single(:integer, value, %Mapping{name: name}) do
    case Integer.parse("#{value}") do
      {num, _} -> num
      :error   -> raise TranslateError, message: "Invalid integer value for #{stringify_key(name)}."
    end
  end
  defp parse_datatype_single(:float, value, %Mapping{name: name}) do
    case Float.parse("#{value}") do
      {num, _} -> num
      :error   -> raise TranslateError, message: "Invalid float value for #{stringify_key(name)}."
    end
  end
  defp parse_datatype_single(:ip, value, %Mapping{name: name}) do
    case String.split("#{value}", ":", trim: true) do
      [ip, port] -> {ip, port}
      _          -> raise TranslateError, message: "Invalid IP format for #{stringify_key(name)}. Expected format: IP:PORT"
    end
  end
  defp parse_datatype_single([enum: valid_values], value, %Mapping{name: name}) do
    parsed = String.to_atom("#{value}")
    if Enum.any?(valid_values, fn v -> v == parsed end) do
      parsed
    else
      raise TranslateError, message: "Invalid enum value for #{stringify_key(name)}."
    end
  end
  defp parse_datatype_single([list: type], value, mapping) when is_list(value) do
    Enum.map(value, &parse_datatype_single(type, &1, mapping))
  end
  defp parse_datatype_single([list: type], value, mapping) do
    raise TranslateError, message: "Invalid value for #{stringify_key(mapping.name)}: Expected list of `#{inspect type}`, got: #{inspect value}"
  end
  defp parse_datatype_single(tuple, value, mapping) when is_tuple(tuple) and is_tuple(value) do
    type_list = Tuple.to_list(tuple)
    values = Tuple.to_list(value)
    cond do
      length(type_list) == length(values) ->
        Enum.zip(type_list, values)
        |> Enum.map(fn {type, val} ->
          parse_datatype_single(type, val, mapping)
        end)
        |> List.to_tuple
      :else ->
        name = Enum.map(mapping.name, &List.to_string/1) |> Enum.join(".")
        raise TranslateError, message: "Invalid format for #{stringify_key(name)}. Expected #{inspect tuple}"
    end
  end
  defp parse_datatype_single({:atom, type}, {k, v}, mapping) do
    {k, parse_datatype_single(type, v, mapping)}
  end
  defp parse_datatype_single(datatype, value, mapping) do
    case is_custom_type?(datatype) do
      {true, mod, _args} ->
        case apply(mod, :convert, [value, mapping]) do
          {:ok, parsed} ->
            parsed
          {:error, reason} when is_binary(reason) ->
            raise TranslateError, message: reason
          {:error, reason} ->
            raise TranslateError, message: Macro.to_string(reason)
        end
      {false, _, _} ->
        nil
    end
  end

  defp sanitize(value) when is_list(value) do
    #this is neccessary for utf8 multibyte content:
    value
    |> :erlang.iolist_to_binary
    |> sanitize()
  end
  defp sanitize(value) do
    bin_value = to_string(value)
    size = byte_size(bin_value) - 2
    case bin_value do
      <<?", string::binary-size(size), ?">> -> string
      _ -> bin_value
    end
  end

  # Write values of the given datatype to their string format (for the .conf)
  defp write_datatype(:atom, value, _setting), do: Atom.to_string(value)
  defp write_datatype(:ip, value, setting) do
    case value do
      {ip, port} -> "#{ip}:#{port}"
      _ -> raise TranslateError, message: "Invalid IP address format for #{setting}. Expected format: {IP, PORT}"
    end
  end
  defp write_datatype([enum: _], value, setting),  do: write_datatype(:atom, value, setting)
  defp write_datatype([list: [list: list_type]], value, setting) when is_list(value) do
    Enum.map(value, fn sublist ->
      elems = Enum.map(sublist, &(write_datatype(list_type, &1, setting))) |> Enum.join(", ")
      <<?[, elems::binary, ?]>>
    end) |> Enum.join(", ")
  end
  defp write_datatype([list: list_types], value, setting)
    when is_list(list_types) and is_list(value) do
    value
    |> Enum.map(fn element ->
      datatype = Conform.Schema.extract_datatype(element)
      cond do
        datatype in list_types ->
          write_datatype(datatype, element, setting)
        :else ->
          raise TranslateError, message: "Invalid datatype for #{setting}. Expected one of: #{inspect list_types}"
      end
    end)
    |> Enum.join(", ")
  end
  defp write_datatype([list: list_type], value, setting) when is_list(value) do
    value |> Enum.map(&(write_datatype(list_type, &1, setting))) |> Enum.join(", ")
  end
  defp write_datatype([list: list_type], value, setting) do
    write_datatype([list: list_type], [value], setting)
  end
  defp write_datatype(:binary, %Regex{} = regex, _setting) do
    "~r/" <> Regex.source(regex) <> "/"
  end
  defp write_datatype(:binary, value, _setting) do
    <<?", "#{value}", ?">>
  end
  defp write_datatype({:atom, type}, {k, v}, setting) do
    converted = write_datatype(type, v, setting)
    <<Atom.to_string(k)::binary, " = ", converted::binary>>
  end
  defp write_datatype(datatype, value, setting) do
    case "#{value}" do
      "" -> <<?", "#{value}", ?">>
      _ -> "#{value}"
    end
  rescue
    Protocol.UndefinedError ->
      msg = "Unable to stringify #{setting}, unrecognized type #{inspect datatype}"
      IO.puts(IO.ANSI.yellow <> msg <> IO.ANSI.reset)
      ""
  end

  defp to_comment(str) do
    String.split(str, "\n", trim: true) |> Enum.map(&add_comment/1) |> Enum.join("\n")
  end

  defp is_custom_type?(datatype) do
    {mod, args} = case datatype do
      [{mod, args}] when is_atom(mod) -> {mod, args}
      mod when is_atom(mod)           -> {mod, nil}
      _                               -> {false, nil}
    end
    if mod do
      [first|_] = Atom.to_charlist(mod)
      mod = case String.match?(<<first::utf8>>, ~r/[A-Z]/) do
        true  -> Module.concat([mod])
        false -> mod
      end
      case Code.ensure_loaded(mod) do
        {:error, :nofile} -> {false, mod, args}
        {:module, mod}    ->
          behaviours = get_in(mod.module_info, [:attributes, :behaviour]) || []
          case Enum.member?(behaviours, Conform.Type) do
            true  -> {true, mod, args}
            false -> {false, mod, args}
          end
      end
    else
      {false, nil, nil}
    end
  end

  defp apply_key_variables(key, []), do: key
  defp apply_key_variables(key, vars) do
    Enum.reduce(vars, key, fn {var, replacement}, acc ->
      Enum.map(acc, fn key_part ->
        case key_part do
          ^var -> replacement
          part -> part
        end
      end)
    end)
  end

  defp stringify_key(key) when is_list(key) do
    key
    |> Enum.map(fn part -> "#{part}" end)
    |> Enum.join(".")
  end

  defp missing_env_var(var, key) do
    "Configuration Error: environment variable $#{var} is not set and no default value for #{key} is present."
  end
end
