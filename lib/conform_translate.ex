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
          result <> "#{comments}\n#{key} = #{Keyword.get(info, :default, :undefined)}\n\n"
        end
      _ -> raise Conform.Schema.SchemaError
    end
  end

  @doc """
  Translate the provided .conf to it's .config representation using the provided schema.
  """
  @spec to_config(term, term) :: term
  def to_config(conf, schema) do
    normalized_conf = Enum.into(conf, HashDict.new, fn({setting, value}) ->
                    key = String.to_atom(setting |> Enum.map(&List.to_string/1) |> Enum.join("."))
                    {key, value}
                  end)
    case schema do
      [mappings: mappings, translations: translations] ->
        # Parse the schema into a map of applications and their settings, applying conf overrides and translations as specified
        settings = Enum.reduce mappings, %{}, fn {key, mapping}, result ->

          # Get the datatype for this mapping, falling back to binary if not defined
          datatype = Dict.get(mapping, :datatype, :binary)

          # conf value takes precident over mapping default
          default_value = Dict.get(mapping, :default, nil)
          parsed_value = case Dict.get(normalized_conf, key) do
            nil        -> default_value
            conf_value ->
              case parse_datatype(datatype, conf_value, key) do
                nil -> conf_value
                val -> val
              end
          end

          # Break the schema setting key name into [app, and setting]
          [app_name|app_setting] = Dict.get(mapping, :to, key |> Atom.to_string) |> String.split(".")

          # Translate parsed value if translation exists
          translated_value = case Dict.get(translations, key) do
            fun when is_function(fun) -> fun.(parsed_value)
            _                         -> parsed_value
          end

          # Add the setting for the given app if one doesn't exist, or update if it does
          app_settings = Map.get(result, app_name, %{})
          app_settings = update_app_settings(app_settings, app_setting, translated_value)
          Map.put(result, app_name, app_settings)
        end
        # Convert config map to Erlang config terms
        settings |> settings_to_config
      _ ->
        raise Conform.Schema.SchemaError
    end
  end

  def update_app_settings(app_settings, key_path, value) do
    update_in_map(app_settings, key_path, value)
  end

  defp update_in_map(map, [key], value) do
    Map.put(map, key, value)
  end
  defp update_in_map(map, [key|path], value) do
    nested_map = Map.get(map, key, %{})
    nested_map = update_in_map(nested_map, path, value)
    Map.put(map, key, nested_map)
  end

  # Add a .conf-style comment to the given line
  defp add_comment(line), do: "# #{line}"

  # Convert config map to Erlang config terms
  # End result: [{:app, [{:key1, val1}, {:key2, val2}, ...]}]
  def settings_to_config(settings) do
    setting_to_config(settings)
  end

  defp setting_to_config(map) when is_map(map) do
    Enum.map(map, fn({k, v}) ->
      {k |> String.to_atom, setting_to_config(v)}
    end)
  end
  defp setting_to_config(value) do
    value
  end

  # Parse the provided value as a value of the given datatype
  defp parse_datatype(:atom, value, _setting),     do: value |> List.to_string |> String.to_atom
  defp parse_datatype(:binary, value, _setting),   do: value |> List.to_string
  defp parse_datatype(:charlist, value, _setting), do: value
  defp parse_datatype(:boolean, value, setting) do
    try do
      case value |> List.to_string |> String.to_existing_atom do
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
    case value |> List.to_string |> Integer.parse do
      {num, _} -> num
      :error   -> raise TranslateError, message: "Invalid integer value for #{setting}."
    end
  end
  defp parse_datatype(:float, value, setting) do
    case value |> List.to_string |> Float.parse do
      {num, _} -> num
      :error   -> raise TranslateError, message: "Invalid float value for #{setting}."
    end
  end
  defp parse_datatype(:ip, value, setting) do
    case value |> List.to_string |> String.split(":", trim: true) do
      [ip, port] -> {ip, port}
      _          -> raise TranslateError, message: "Invalid IP format for #{setting}. Expected format: IP:PORT"
    end
  end
  defp parse_datatype([enum: valid_values], value, setting) do
    parsed = value |> List.to_string |> String.to_atom
    if Enum.any?(valid_values, fn v -> v == parsed end) do
      parsed
    else
      raise TranslateErorr, message: "Invalid enum value for #{setting}."
    end
  end
  defp parse_datatype(_datatype, _value, _setting), do: nil
end
