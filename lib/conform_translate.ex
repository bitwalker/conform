defmodule Conform.Translate do

  defexception TranslateError, message: "Translation failed!"

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

  def to_config(conf, schema) do
    case schema do
      [mappings: mappings, translations: translations] ->
        parsed   = Conform.Parse.parse(conf)
        settings = Enum.reduce parsed, %{}, fn {setting, value}, result ->
          key = binary_to_atom(setting |> Enum.map(&String.from_char_data!/1) |> Enum.join("."))
          # If no mapping is defined, just return the current config map,
          # otherwise, parse the config for this mapping
          case Keyword.get(mappings, key) do
            nil  -> result
            info ->
              translation        = Keyword.get(translations, key)
              [app, app_setting] = Keyword.get(info, :to) |> String.split(".", parts: 2)
              default_value      = Keyword.get(info, :default, nil)
              datatype           = Keyword.get(info, :datatype, :binary)
              # Parse the provided value according to the defined datatype
              parsed_value = case datatype do
                :atom ->
                  value |> String.from_char_data! |> binary_to_atom
                :binary ->
                  value |> String.from_char_data!
                :charlist ->
                  value
                :integer -> 
                  case value |> String.from_char_data! |> Integer.parse do
                    {num, _} -> num
                    :error   -> raise TranslateError, message: "Invalid integer value for #{setting}."
                  end
                :float ->
                  case value |> String.from_char_data! |> Float.parse do
                    {num, _} -> num
                    :error   -> raise TranslateError, message: "Invalid float value for #{setting}."
                  end
                :ip ->
                  case value |> String.from_char_data! |> String.split(":", trim: true) do
                    [ip, port] -> {ip, port}
                    _          -> raise TranslateError, message: "Invalid IP format for #{setting}. Expected format: IP:PORT"
                  end
                [enum: valid_values] ->
                  parsed = value |> String.from_char_data! |> binary_to_atom
                  if Enum.any?(valid_values, fn v -> v == parsed end) do
                    parsed
                  else
                    raise TranslateErorr, message: "Invalid enum value for #{setting}."
                  end
                _ ->
                  default_value
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
        Enum.reduce(settings, [], fn {app, settings}, config ->
          [{app |> binary_to_atom, (for {k, v} <- settings, into: [], do: {k |> binary_to_atom, v})} | config]
        end)
      _ ->
        raise Conform.Schema.SchemaError
    end
  end

  defp add_comment(line), do: "# #{line}"
end