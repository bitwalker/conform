defmodule Conform.Schema do
  @moduledoc """
  This module is responsible for the handling of schema files.
  """

  @doc """
  This exception reflects an issue with the schema
  """
  defexception SchemaError, message: "Invalid schema. Should be a keyword list containing :mappings and :translations keys."

  @doc """
  Load a schema from the provided file path
  """
  @spec load(binary) :: term
  def load(path) do
    case path |> Code.eval_file do
      {[mappings: _, translations: _] = schema, _} ->
        schema
      _ ->
        raise SchemaError
    end
  end

  @doc """
  Convert configuration in Elixir terms to schema format.
  """
  @spec from_config([] | [{atom, term}]) :: [{atom, term}]
  def from_config([]), do: empty
  def from_config(config) when is_list(config) do
    [ mappings:     to_schema(config),
      translations: [] ]
  end

  def empty do
    [ mappings:     [],
      translations: [] ]
  end

  defp to_schema([]),                     do: []
  defp to_schema([{app, settings}|rest]), do: to_schema(app, settings, rest)
  defp to_schema(app, settings, config) do
    mappings = Enum.map(settings, fn {k, v} -> to_mapping("#{app}", k, v) end) |> List.flatten
    mappings ++ to_schema(config)
  end

  defp to_mapping(key, setting, value) do
    case Keyword.keyword?(value) do
      true ->
        for {k, v} <- value, into: [] do
          to_mapping("#{key}.#{setting}", k, v)
        end
      false ->
        datatype = extract_datatype(value)
        setting_name = "#{key}.#{setting}"
        ["#{setting_name}": [
          doc: "Documentation for #{setting_name} goes here.",
          to: setting_name,
          datatype: datatype,
          default:  convert_to_datatype(datatype, value)
        ]]
    end
  end

  defp extract_datatype(v) when is_atom(v),    do: :atom
  defp extract_datatype(v) when is_binary(v),  do: :binary
  defp extract_datatype(v) when is_boolean(v), do: :boolean
  defp extract_datatype(v) when is_integer(v), do: :integer
  defp extract_datatype(v) when is_float(v),   do: :float
  # Default lists to binary, unless it's a charlist
  defp extract_datatype(v) when is_list(v) do 
    case :io_lib.char_list(v) do
      true  -> :charlist
      false -> :binary
    end
  end
  defp extract_datatype(_), do: :binary

  defp convert_to_datatype(:binary, v) when is_binary(v),     do: v
  defp convert_to_datatype(:binary, v) when not is_binary(v), do: nil
  defp convert_to_datatype(_, v), do: v

end