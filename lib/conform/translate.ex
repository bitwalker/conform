defmodule Conform.Translate do
  @moduledoc """
  This module is responsible for translating either from .conf -> .config or
  from .schema.exs -> .conf
  """

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
    case schema do
      [mappings: mappings, translations: _] ->
        Enum.reduce mappings, "", fn {key, info}, result ->
          comments = Keyword.get(info, :doc, "")
            |> String.split("\n", trim: true)
            |> Enum.map(&add_comment/1)
            |> Enum.join("\n")
          # If the datatype of this mapping is an enum,
          # write out the allowed values
          datatype = Keyword.get(info, :datatype, :binary)
          result = case datatype do
            [enum: values] ->
              allowed = "# Allowed values: #{Enum.join(values, ", ")}\n"
              <<result::binary, comments::binary, ?\n, allowed::binary>>
            _ ->
              <<result::binary, comments::binary, ?\n>>
          end
          case Keyword.get(info, :default) do
            nil ->
              <<result::binary, "# #{key} = \n\n">>
            default ->
              <<result::binary, "#{key} = #{write_datatype(datatype, default, key)}\n\n">>
          end
        end
      _ -> raise Conform.Schema.SchemaError
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

    case schema do
      [mappings: mappings, translations: translations] ->
        # get complex data types
        {mappings, complex} = get_complex(mappings, translations, normalized_conf)
        # Parse the .conf into a map of applications and their settings, applying translations where defined
        settings = Enum.reduce mappings, %{}, fn {key, mapping}, result ->
          # Get the datatype for this mapping, falling back to binary if not defined
          datatype = Keyword.get(mapping, :datatype, :binary)
          # Get the default value for this mapping, if defined
          default_value = Keyword.get(mapping, :default, nil)
          # parsed value returns the value with valid data type
          parsed_value  = case get_in(normalized_conf, [key]) do
            nil        -> default_value
            conf_value ->
              case parse_datatype(datatype, conf_value, key) do
                nil -> conf_value
                val -> val
              end
          end

          # Break the schema key name into it's parts, [app, [key1, key2, ...]]
          [app_name|setting_path] = Keyword.get(mapping, :to, key |> Atom.to_string) |> String.split(".")

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
                                 parsed_value
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
          end) |> :lists.flatten

          result = update_in!(result, [app_name|setting_path |> repath], translated_value)

          case res do
            [] ->
              result
            [records] ->
              update_in!(records, [app_name|setting_path |> repath], translated_value)
          end
        end

        # One last pass to catch any config settings not present in the schema, but
        # which should still be present in the merged configuration
        merged = config |> Enum.reduce(settings, fn {app, app_config}, acc ->
          app_name = app |> Atom.to_string
          # Ensure this app is present in the merged config
          acc = case Map.has_key?(acc, app_name) do
            true  -> acc
            false -> put_in(acc, [app_name], %{})
          end
          # Add missing settings to merged config from config.exs
          app_config |> Enum.reduce(acc, fn {key, value}, acc ->
            key_name = key |> Atom.to_string
            case get_in(acc, [app_name, key_name]) do
              nil -> put_in(acc, [app_name, key_name], value)
              _   -> acc
            end
          end)
        end)

        # Convert config map to Erlang config terms
        merged |> settings_to_config
      _ ->
        raise Conform.Schema.SchemaError
    end
  end

  defp get_complex(mappings, translations, normalized_conf) do
    complex = get_complex([], mappings)
    mappings = delete_complex([], mappings) |> :lists.reverse
    complex_names = get_complex_names([], complex, normalized_conf)
    complex = Enum.reduce(complex, [], fn({map_key, mapping}, result) ->
      data = Enum.map(complex_names, fn({complex_data_type, complex_type_name}) ->
        {_, p} = Regex.compile(map_key |> Atom.to_string)
        case Regex.run(p, complex_data_type) do
          nil -> []
          _ ->
            {complex_data_type, complex_type_name |> String.to_atom,
             Enum.map(mapping, fn({complex_key, complex_mappings}) ->
               field = String.split(complex_key |> Atom.to_string, "*.") |> List.last |> String.to_atom
               datatype = Keyword.get(complex_mappings, :datatype, :binary)
               default_value = Keyword.get(complex_mappings, :default, nil)
               case get_in_complex(complex_type_name, normalized_conf, [complex_key]) do
                 [] ->
                   {field, default_value}
                 conf_value -> case parse_datatype(datatype, conf_value, complex_key) do
                                 nil -> {field, conf_value}
                                 val -> {field, val}
                               end
               end
             end)}
        end
      end) |> :lists.flatten
      update_complex_acc(mapping, result, translations, data)
    end)
    {mappings, complex}
  end

  defp update_complex_acc([], result, _, _), do: result
  defp update_complex_acc([{_, map} | mapping], result, translations, data) do
    map_key = Keyword.get(map, :to)
    [app_name, path]  = Keyword.get(map, :to) |> String.split(".")
    map_key = map_key <> ".*"
    result = case result do
      [] ->
        update_in!(%{}, [app_name, path], build_complex(mapping, translations, data, map_key |> String.to_atom) |> :lists.flatten)
      _ ->
        update_in!(result, [app_name, path], build_complex(mapping, translations, data, map_key |> String.to_atom) |> :lists.flatten)
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
  defp get_complex(complex, [{key, _} | mappings]) do
    case Regex.run(~r/\.\*/, key |> to_string) do
      nil ->
        get_complex(complex, mappings)
      _ ->
        mappings = List.keydelete(mappings, key, 0)
        [pattern | _] = String.split(key |> to_string, ".")
        pattern_length = byte_size(pattern)
        result = Enum.filter(mappings,
          fn({k, _}) ->
            case :re.run(Atom.to_string(k),  key |> to_string) do
              :nomatch -> false
              {:match, [{0, l}]} when l < pattern_length -> false
              _ -> true
            end
          end)
        result = Enum.filter([{key, result} | complex] |> :lists.flatten,
          fn({_, complex_mappings}) ->
            case complex_mappings do
              [] -> false
              _ -> true
            end
          end)
        get_complex(result, mappings)
    end
  end

  defp get_in_complex(name, normalized_conf, [key]) do
    res = Enum.filter(normalized_conf,
      fn({complex_key, _}) ->
        {_, pattern} = Regex.compile(key |> Atom.to_string)
        case Regex.run(pattern, complex_key |> Atom.to_string) do
          nil -> false
          _ -> true
        end
      end)

    res = Enum.filter(res, fn({complex_key, _}) ->
      {_, wildcard_name} = get_name_under_wildcard(key, complex_key)
      wildcard_name == name
    end)

    case res do
      [] -> []
      [{_, val}] -> val
    end
  end

  defp get_complex_names(result, [], _), do: result |> :lists.usort
  defp get_complex_names(result, [{pattern, _} | complex], normalized_conf) do
    res = Enum.map(normalized_conf,
      fn{complex_key, _} ->
        {_, regexp} = Regex.compile(pattern |> Atom.to_string)
        case Regex.run(regexp, complex_key |> Atom.to_string) do
          nil -> []
          _ -> get_name_under_wildcard(pattern, complex_key)
        end
      end)
    get_complex_names([res | result] |> :lists.flatten, complex, normalized_conf)
  end

  defp get_name_under_wildcard(pattern, name) do
    pattern = String.split(pattern |> Atom.to_string, ".*") |> List.first
    {pattern, String.split(name |> Atom.to_string, pattern <> ".") |> List.last |> String.split(".") |> List.first}
  end

  defp build_complex(mapping, translations, data, map_key) do
    Enum.map(data, fn({_, field_name, data}) ->
      case get_in(translations, [map_key]) do
        fun when is_function(fun) ->
          map = Enum.reduce(data, %{}, fn({k, v}, acc) -> Map.put(acc, k, v) end)
          fun.(mapping, {field_name, map}, []) |> :lists.flatten
      end
    end)
  end

  defp repath(setting_path) do
    uc_set = Enum.map(?A..?Z, fn i -> List.to_string([i]) end) |> Enum.into(HashSet.new)
    new_path = repath(setting_path, uc_set, [], [])
    |> List.flatten
    |> Enum.reverse
    new_path
  end

  defp repath([], _uc_set, [], total_acc) do
    total_acc
  end
  defp repath([], _uc_set, this_acc, total_acc) do
    [rev_join_key(this_acc)|total_acc]
  end
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


  defp update_in!(coll, key_path, value) do
    update_in!(coll, key_path, value, [])
  end
  defp update_in!(coll, [], value, path) do
    put_in(coll, path, value)
  end
  defp update_in!(coll, [key|rest], value, acc) do
    path = acc ++ [key]
    case get_in(coll, path) do
      nil ->
        put_in(coll, path, %{}) |> update_in!(rest, value, path)
      _ ->
        update_in!(coll, rest, value, path)
    end
  end

  # Add a .conf-style comment to the given line
  defp add_comment(line), do: "# #{line}"

  # Convert config map to Erlang config terms
  # End result: [{:app, [{:key1, val1}, {:key2, val2}, ...]}]
  defp settings_to_config(map) when is_map(map) do
    map |> Enum.map(&settings_to_config/1)
  end
  defp settings_to_config({key, value}) when is_map(value) do
    {key |> String.to_atom, settings_to_config(value)}
  end
  defp settings_to_config({key, value}) do
    {key |> String.to_atom, value}
  end
  defp settings_to_config(value), do: value

  # Parse the provided value as a value of the given datatype
  defp parse_datatype(:atom, value, _setting),     do: "#{value}" |> String.to_atom
  defp parse_datatype(:binary, value, _setting),   do: "#{value}"
  defp parse_datatype(:string, value, _setting),   do: "#{value}"
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
  defp parse_datatype([list: list_type], value, setting) do
    "#{value}"
    |> String.split(",")
    |> Enum.map(&String.strip/1)
    |> Enum.map(&(parse_datatype(list_type, &1, setting)))
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
  defp write_datatype([list: list_type], value, setting) when is_list(value) do
    value |> Enum.map(&(write_datatype(list_type, &1, setting))) |> Enum.join(", ")
  end
  defp write_datatype([list: list_type], value, setting) do
    write_datatype([list: list_type], [value], setting)
  end
  defp write_datatype(:binary, value, _setting) do
    <<?", "#{value}", ?">>
  end
  defp write_datatype(_datatype, value, _setting), do: "#{value}"

end
