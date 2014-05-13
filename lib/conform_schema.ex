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
end