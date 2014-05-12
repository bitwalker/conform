defmodule Conform.Schema do
  defexception SchemaError, message: "Invalid schema. Should be a keyword list containing :mappings and :translations keys."

  def load(path) do
    case path |> Code.eval_file do
      {[mappings: _, translations: _] = schema, _} ->
        schema
      _ ->
        raise SchemaError
    end
  end
end