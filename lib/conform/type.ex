defmodule Conform.Type do
  @moduledoc """
  Defines the behaviour for custom types.
  """

  defmacro __using__(_) do
    quote do
      @behaviour Conform.Type
    end
  end

  @doc """
  Return a string to produce documentation for the given type based on it's valid values (if specified).
  If nil is returned, the documentation specified in the schema will be used instead (if present).
  """
  @callback to_doc(term) :: nil | String.t
  @doc """
  Converts the .conf value to this data type.
  Should return the translated value or {:error, reason}
  """
  @callback convert(term, Conform.Schema.Mapping.t) :: {:ok, term} | {:error, term}

end
