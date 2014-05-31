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
    case schema do
      [mappings: mappings, translations: translations] ->
        # Parse the .conf into a map of applications and their settings, applying translations where defined
        settings = Enum.reduce conf, %{}, fn {setting, value}, result ->
          # Convert the parsed setting key into the atom used in the schema
          key = binary_to_atom(setting |> Enum.map(&List.to_string/1) |> Enum.join("."))
          # Look for a mapping with the provided name
          case Keyword.get(mappings, key) do
            # If no mapping is defined, just return the current config map,
            nil  -> result
            # Otherwise, parse the config for this mapping
            info ->
              # Get the translation function if one is defined
              translation        = Keyword.get(translations, key)
              # Break the setting key name into [app, and setting]
              [app, app_setting] = Keyword.get(info, :to, key |> atom_to_binary) |> String.split(".", parts: 2)
              # Get the default value for this mapping, if defined
              default_value      = Keyword.get(info, :default, nil)
              # Get the datatype for this mapping, falling back to binary if not defined
              datatype           = Keyword.get(info, :datatype, :binary)
              # Parse the provided value according to the defined datatype
              parsed_value = case parse_datatype(datatype, value, setting) do
                nil -> default_value
                val -> val
              end
              # Translate parsed value if translation exists
              translated_value = case translation do
                fun when is_function(fun) -> fun.(parsed_value)
                _                         -> parsed_value
              end
              # Add the setting for the given app if one doesn't exist, or update if it does
              current = Map.get(result, app, %{})
              Map.put(result, app, Map.put(current, app_setting, translated_value))
          end
        end
        # Convert config map to Erlang config terms
        settings |> settings_to_config
      _ ->
        raise Conform.Schema.SchemaError
    end
  end

  # Add a .conf-style comment to the given line
  defp add_comment(line), do: "# #{line}"

  # Convert config map to Erlang config terms
  # End result: [{:app, [{:key1, val1}, {:key2, val2}, ...]}]
  defp settings_to_config(settings) do
    for {app, settings} <- settings, into: [] do
      { app |> binary_to_atom, (for {k, v} <- settings, into: [], do: {k |> binary_to_atom, v}) }
    end
  end

  # Parse the provided value as a value of the given datatype
  defp parse_datatype(:atom, value, _setting),     do: value |> List.to_string |> binary_to_atom
  defp parse_datatype(:binary, value, _setting),   do: value |> List.to_string
  defp parse_datatype(:charlist, value, _setting), do: value
  defp parse_datatype(:boolean, value, setting) do
    try do
      case value |> List.to_string |> binary_to_existing_atom do
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
    parsed = value |> List.to_string |> binary_to_atom
    if Enum.any?(valid_values, fn v -> v == parsed end) do
      parsed
    else
      raise TranslateErorr, message: "Invalid enum value for #{setting}."
    end
  end
  defp parse_datatype(_datatype, _value, _setting), do: nil
end