defmodule Conform.Translate do
  @moduledoc """
  This module is responsible for translating either from .conf -> .config or
  from .schema.exs -> .conf
  """

  @list_types [:list, :enum, :complex]

  @doc """
  This exception reflects an issue with the translation process
  """
  defmodule TranslateError do
    defexception message: "Translation failed!"
  end

  @doc """
  Translate the provided schema to it's default .conf representation
  """
  @spec to_conf([{atom, term}]) :: binary
  def to_conf(schema) do
    schema = Keyword.delete(schema, :import)
    case schema do
      [mappings: mappings, translations: _] ->
        Enum.reduce mappings, "", fn {key, info}, result ->
          # If the datatype of this mapping is an enum,
          # write out the allowed values
          datatype             = Keyword.get(info, :datatype, :binary)
          doc                  = Keyword.get(info, :doc, "")
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
          default = Keyword.get(info, :default)
          case default do
            nil ->
              <<result::binary, "# #{key} = \n\n">>
            default ->
              <<result::binary, "#{key} = #{write_datatype(datatype, default, key)}\n\n">>
          end
        end
      _ ->
        raise Conform.Schema.SchemaError
    end
  end

  @doc """
  Translate the provided .conf to it's .config representation using the provided schema.
  """
  @spec to_config([{term, term}] | [], [{term, term}] | [], [{term, term}]) :: term
  def to_config(config, conf, schema) do
    # Convert the .conf into a map of key names to values
    normalized_conf =
      for {setting, value} <- conf, into: %{} do
        key = setting
              |> Enum.map(&List.to_string/1)
              |> Enum.join(".")
              |> String.to_atom
        {key, value}
    end

    schema = Keyword.delete(schema, :import)
    case schema do
      [mappings: mappings, translations: translations] ->
        # get complex data types
        {mappings, complex} = get_complex(mappings, translations, normalized_conf)
        # Parse the .conf into a map of applications and their settings, applying translations where defined
        settings = Enum.reduce(mappings, complex,
          fn {key, mapping}, result ->
            # Get the datatype for this mapping, falling back to binary if not defined
            datatype = Keyword.get(mapping, :datatype, :binary)
            # Get the default value for this mapping, if defined
            default_value = Keyword.get(mapping, :default, nil)
            # parsed value returns the value with valid data type
            parsed_value = case get_in(normalized_conf, [key]) do
              nil        -> default_value
              conf_value ->
                case parse_datatype(datatype, conf_value, key) do
                  nil ->
                    conf_value
                  val -> val
                end
            end

            # Break the schema key name into it's parts, [app, [key1, key2, ...]]
            [app_name|setting_path] = Keyword.get(mapping, :to, key |> Atom.to_string)
                                      |> String.split(".")
                                      |> Enum.map(&String.to_atom/1)

            # Get the translation function is_function one is defined
            translated_value = case get_in(translations, [key]) do
              fun when is_function(fun) ->
                case :erlang.fun_info(fun, :arity) do
                  {:arity, 2} ->
                    fun.(mapping, parsed_value)
                  {:arity, 3} ->
                    current_value = get_in(result, [app_name|setting_path])
                    fun.(mapping, parsed_value, current_value)
                  _ ->
                    Conform.Utils.error("Invalid translation function arity for #{key}. Must be /2 or /3")
                    exit(1)
                end
              _ ->
                # if we have no the translation for the current key
                # in the schema, maybe we are dealing with a custom
                # type.
                case is_custom_type?(datatype) do
                  {true, mod, _args} ->
                    translate_custom_type(mod, mapping, key, normalized_conf, parsed_value, result, app_name, setting_path)
                  _ ->
                    parsed_value
                end
            end

            # Update this application setting, using empty maps as the default
            # value when working down `setting_path` and complex types
            res = Enum.map(complex, fn({app, complex_map}) ->
              case app == app_name do
                true ->
                  Enum.reduce(complex_map, result, fn({complex_key, complex_val}, acc) ->
                    update_in!(acc, [app_name|[complex_key] |> repath], complex_val)
                  end)
                false ->
                  []
              end
            end) |> List.flatten

            result = update_in!(result, [app_name|setting_path |> repath], translated_value)
            result = case res do
              [] ->
                result
              records ->
                update_in!(records, [app_name|setting_path |> repath], translated_value)
            end
            result
            |> Stream.map(fn {key, value} -> {key, Enum.sort_by(value, fn {k,_} -> k end)} end)
            |> Enum.sort_by(fn {key, _} -> key end)
        end)

        # One last pass to catch any config settings not present in the schema, but
        # which should still be present in the merged configuration
        merged = config |> Enum.reduce(settings, fn {app, app_config}, acc ->
          # Ensure this app is present in the merged config
          acc = case Keyword.has_key?(acc, app) do
            true  -> acc
            false -> put_in(acc, [app], [])
          end
          # Add missing settings to merged config from config.exs
          app_config |> Enum.reduce(acc, fn {key, value}, acc ->
            case get_in(acc, [app, key]) do
              nil -> put_in(acc, [app, key], value)
              _   -> acc
            end
          end)
          |> Enum.map(fn
            {key, value} when is_list(value) ->
              {key, Enum.sort_by(value, fn {k, _} -> k end)}
            x ->
              x
          end)
        end)


        # Convert config map to Erlang config terms
        merged |> settings_to_config
      _ ->
        raise Conform.Schema.SchemaError
    end
  end

  defp get_complex(mappings, translations, normalized_conf) do
    complex       = get_complex([], mappings)
    mappings      = delete_complex([], mappings) |> :lists.reverse
    complex_names = get_complex_names([], complex, normalized_conf)

    complex = Enum.reduce(complex, [], fn {map_key, mapping}, result ->
      data = Enum.map(complex_names, fn {complex_data_type, complex_type_name} ->
        {_, p} = Regex.compile(map_key |> Atom.to_string)
        case Regex.run(p, complex_data_type) do
          nil -> []
          _ ->
            case mapping do
              [] ->
                field         = String.to_atom(complex_type_name)
                datatype      = get_in(mappings, [map_key, :datatype]) || :binary
                default_value = get_in(mappings, [map_key, :default])
                conf_key      = String.to_atom(complex_data_type <> "." <> complex_type_name)
                case get_in_complex(complex_type_name, normalized_conf, [conf_key]) do
                  [] -> {field, default_value}
                  conf_value ->
                    case parse_datatype(datatype, conf_value, complex_data_type <> "." <> complex_type_name) do
                      nil -> {field, conf_value}
                      val -> {field, val}
                    end
                end
              _ ->
                {complex_data_type, complex_type_name |> String.to_atom,
                 Enum.map(mapping, fn {complex_key, complex_mappings} ->
                   field         = String.split(Atom.to_string(complex_key), "*.")
                                   |> List.last
                                   |> String.to_atom
                   datatype      = Keyword.get(complex_mappings, :datatype, :binary)
                   default_value = Keyword.get(complex_mappings, :default, nil)

                   case get_in_complex(complex_type_name, normalized_conf, [complex_key]) do
                     []         -> {field, default_value}
                     conf_value ->
                      case parse_datatype(datatype, conf_value, complex_key) do
                        nil -> {field, conf_value}
                        val -> {field, val}
                      end
                   end
                 end)}
              end
          end
      end) |> List.flatten

      update_complex_acc(mapping, result, translations, data)
    end)

    {mappings, complex}
  end

  defp update_complex_acc([], result, _, _), do: result
  defp update_complex_acc([{from_key, map} | mapping], result, translations, data) do
    to_key            = String.to_atom(Keyword.get(map, :to) <> ".*")
    [app_name, path]  = Keyword.get(map, :to) |> String.split(".") |> Enum.map(&String.to_atom/1)
    built = build_complex(mapping, translations, data, from_key, to_key)
            |> List.flatten
            |> Enum.sort_by(fn {k, _} -> k end)
    result = case result do
      [] -> update_in!([], [app_name, path], built)
      _  -> update_in!(result, [app_name, path], built)
    end
    update_complex_acc(mapping, result, translations, data)
  end

  defp delete_complex(mappings, []), do: mappings
  defp delete_complex(collect_mappings, [{key, maps} | mappings]) do
    case Regex.run(~r/\.\*/, key |> to_string) do
      nil -> delete_complex([{key,maps} | collect_mappings], mappings)
      _ ->   delete_complex(collect_mappings, mappings)
    end
  end

  defp get_complex(complex, []), do: complex
  defp get_complex(complex, [{key, _} = mapping | mappings]) do
    case Regex.run(~r/\.\*/, to_string(key)) do
      nil ->
        get_complex(complex, mappings)
      _ ->
        mappings       = List.keydelete(mappings, key, 0)
        [pattern | _]  = String.split(to_string(key), ".")
        pattern_length = byte_size(pattern)

        result = Enum.filter(mappings,
          fn {k, _}  ->
            case :re.run(Atom.to_string(k), to_string(key)) do
              :nomatch -> false
              {:match, [{0, l}]} when l < pattern_length -> false
              _ -> true
            end
          end)

        case result do
          [] -> get_complex(List.flatten([{key, [mapping]} | complex]), mappings)
          _  -> get_complex(List.flatten([{key, result} | complex]), mappings)
        end
    end
  end

  defp get_in_complex(name, normalized_conf, [key]) do
    res = Enum.filter(normalized_conf,
      fn {complex_key, _} ->
        {_, pattern} = key |> Atom.to_string |> String.replace(".*.", "\\.[\\w]+\\.") |> Regex.compile
        case Regex.run(pattern, Atom.to_string(complex_key)) do
          nil -> false
          _   -> true
        end
      end)

    res = Enum.filter(res, fn {complex_key, _} ->
      case complex_key do
        ^key ->
          true
        _ ->
          {_, wildcard_name} = get_name_under_wildcard(key, complex_key)
          wildcard_name == name
      end
    end)

    case res do
      []         -> []
      [{_, val}] -> val
    end
  end

  defp get_complex_names(result, [], _), do: result |> :lists.usort
  defp get_complex_names(result, [{pattern, _} | complex], normalized_conf) do
    res = Enum.map(normalized_conf, fn {complex_key, _} ->
      {_, regexp} = Regex.compile(Atom.to_string(pattern))
      case Regex.run(regexp, Atom.to_string(complex_key)) do
        nil -> []
        _   -> get_name_under_wildcard(pattern, complex_key)
      end
    end)

    get_complex_names(List.flatten([res | result]), complex, normalized_conf)
  end

  defp get_name_under_wildcard(pattern, name) do
    pattern = String.split(Atom.to_string(pattern), ".*")
              |> List.first
    result = String.split(Atom.to_string(name), pattern <> ".")
             |> List.last
             |> String.split(".")
             |> List.first
    {pattern, result}
  end

  defp build_complex(mapping, translations, data, from_key, to_key) do
    Enum.map(data, fn {_, field_name, data} ->
      case get_in(translations, [to_key]) do
        fun when is_function(fun) ->
          map = Enum.reduce(data, %{}, fn
            {k, v}, acc ->
              case k do
                ^from_key -> Map.put(acc, field_name, v)
                ^to_key   -> Map.put(acc, field_name, v)
                _         -> Map.put(acc, k, v)
              end
          end)
          fun.(mapping, {field_name, map}, []) |> List.flatten
      end
    end)
  end

  defp repath(setting_path) do
    uc_set   = Enum.map(?A..?Z, fn i -> <<i::utf8>> end) |> Enum.into(HashSet.new)
    setting_path
    |> Enum.map(&Atom.to_string/1)
    |> repath(uc_set, [], [])
    |> List.flatten
    |> Enum.reverse
    |> Enum.map(&String.to_atom/1)
  end

  defp repath([], _uc_set, [], total_acc),       do: total_acc
  defp repath([], _uc_set, this_acc, total_acc), do: [rev_join_key(this_acc)|total_acc]
  defp repath([next|tail], uc_set, this_acc, total_acc) do
    case Set.member?(uc_set, String.at(next, 0)) do
      true ->
        repath(tail, uc_set, [next|this_acc], total_acc)
      false ->
        repath(tail, uc_set, [], [next|[rev_join_key(this_acc)|total_acc]])
    end
  end

  defp rev_join_key([]), do: []
  defp rev_join_key(key_frags) when is_list(key_frags) do
    key_frags |> Enum.reverse |> Enum.join(".")
  end

  defp update_in!(coll, key_path, value), do: update_in!(coll, key_path, value, [])
  defp update_in!(coll, [], value, path), do: put_in(coll, path, value)
  defp update_in!(coll, [key|rest], value, acc) do
    path = acc ++ [key]
    case get_in(coll, path) do
      nil -> put_in(coll, path, []) |> update_in!(rest, value, path)
      _   -> update_in!(coll, rest, value, path)
    end
  end

  # Add a .conf-style comment to the given line
  defp add_comment(line), do: "# #{line}"

  # Convert config map to Erlang config terms
  # End result: [{:app, [{:key1, val1}, {:key2, val2}, ...]}]
  defp settings_to_config(map) when is_map(map),            do: Enum.map(map, &settings_to_config/1)
  defp settings_to_config({key, value}) when is_map(value), do: {String.to_atom(key), settings_to_config(value)}
  defp settings_to_config({key, value}),                    do: {String.to_atom(key), value}
  defp settings_to_config(value),                           do: value

  # Parse the provided value as a value of the given datatype
  defp parse_datatype(:atom, value, _setting),     do: "#{value}" |> String.to_atom
  defp parse_datatype(:binary, value, _setting),   do: "#{value}"
  defp parse_datatype(:charlist, value, _setting), do: '#{value}'
  defp parse_datatype(:boolean, value, setting) do
    try do
      case "#{value}" |> String.to_existing_atom do
        true  -> true
        false -> false
        _     -> raise TranslateError, messagae: "Invalid boolean value for #{setting}."
      end
    rescue
      ArgumentError ->
        raise TranslateError, messagae: "Invalid boolean value for #{setting}."
    end
  end
  defp parse_datatype(:integer, value, setting) do
    case "#{value}" |> Integer.parse do
      {num, _} -> num
      :error   -> raise TranslateError, message: "Invalid integer value for #{setting}."
    end
  end
  defp parse_datatype(:float, value, setting) do
    case "#{value}" |> Float.parse do
      {num, _} -> num
      :error   -> raise TranslateError, message: "Invalid float value for #{setting}."
    end
  end
  defp parse_datatype(:ip, value, setting) do
    case "#{value}" |> String.split(":", trim: true) do
      [ip, port] -> {ip, port}
      _          -> raise TranslateError, message: "Invalid IP format for #{setting}. Expected format: IP:PORT"
    end
  end
  defp parse_datatype([enum: valid_values], value, setting) do
    parsed = "#{value}" |> String.to_atom
    if Enum.any?(valid_values, fn v -> v == parsed end) do
      parsed
    else
      raise TranslateErorr, message: "Invalid enum value for #{setting}."
    end
  end
  defp parse_datatype([list: :ip], value, setting) do
    "#{value}"
    |> String.split(",")
    |> Enum.map(&String.strip/1)
    |> Enum.map(&(parse_datatype(:ip, &1, setting)))
  end
  defp parse_datatype([list: list_type], value, setting) do
    case :io_lib.char_list(value) do
      true  ->
        "#{value}"
        |> String.split(",")
        |> Enum.map(&String.strip/1)
        |> Enum.map(&(parse_datatype(list_type, &1, setting)))
      false ->
        Enum.map(value, &(parse_datatype(list_type, &1, setting)))
    end
  end
  defp parse_datatype({:atom, type}, {k, v}, setting) do
    {k, parse_datatype(type, v, setting)}
  end
  defp parse_datatype(_datatype, _value, _setting), do: nil

  # Write values of the given datatype to their string format (for the .conf)
  defp write_datatype(:atom, value, _setting), do: value |> Atom.to_string
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
  defp write_datatype([list: list_type], value, setting) when is_list(value) do
    value |> Enum.map(&(write_datatype(list_type, &1, setting))) |> Enum.join(", ")
  end
  defp write_datatype([list: list_type], value, setting) do
    write_datatype([list: list_type], [value], setting)
  end
  defp write_datatype(:binary, value, _setting) do
    <<?", "#{value}", ?">>
  end
  defp write_datatype({:atom, type}, {k, v}, setting) do
    converted = write_datatype(type, v, setting)
    <<Atom.to_string(k)::binary, " = ", converted::binary>>
  end
  defp write_datatype(_datatype, value, _setting), do: "#{value}"

  defp to_comment(str) do
    String.split(str, "\n", trim: true) |> Enum.map(&add_comment/1) |> Enum.join("\n")
  end

  defp custom_parsed_value(mod, key, normalized_conf, default_value) do
    case get_in(normalized_conf, [key]) do
      nil -> default_value
      val ->
        case mod.parse_datatype(key, val) do
          {:ok, result}     -> result
          {:error, _} = err -> err
        end
    end
  end

  defp translate_custom_type(mod, mapping, key, normalized_conf, parsed_value, result, app_name, setting_path) do
    parsed_value = custom_parsed_value(mod, key, normalized_conf, parsed_value)
    accumulator  = get_in(result, [app_name | setting_path])
    mod.translate(mapping, parsed_value, accumulator)
  end

  defp is_custom_type?(datatype) do
    {mod, args} = case datatype do
      [{mod, args}]         -> {mod, args}
      mod                   -> {mod, nil}
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
  end
end
