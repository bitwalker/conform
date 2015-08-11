defmodule Conform.Type do
  @moduledoc """
  Defines the behaviour for custom types.
  """
  use Behaviour

  defmacro __using__(_) do
    quote do
      @behaviour Conform.Type
    end
  end

  @doc """
  Return a string to produce documentation for the given type based on it's valid values (if specified).
  Return false if you wish to instead use the documentation specified in the schema.
  """
  defcallback to_doc(term) :: String.t | false
  @doc """
  Translate an input value based on the provided mapping.
  Should return the translated value or {:error, reason}
  """
  defcallback translate(mapping :: term, value :: term, acc :: list(term)) :: term | {:error, term}
  @doc """
  By default conform reads values as string. Implement your own conversion using this callback.
  If you implement your own conversion, you must return either {:ok, val} | {:error, reason}
  """
  defcallback parse_datatype(atom, term) :: {:ok, term} | {:error, term}

end
