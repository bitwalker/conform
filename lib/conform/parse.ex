defmodule Conform.Parse do
  @moduledoc """
  This module is responsible for parsing *.conf files
  """

  defmodule ParseError do
    defexception message: "Invalid conf file, please double check that it is valid."
  end

  @doc """
  Parse the file at the provided path as a .conf file,
  returning either the parsed terms, or raising a ParseError if parsing fails.
  """
  @spec file!(binary) :: term | no_return
  def file!(path) do
    case :conform_parse.file(path) do
      terms when is_list(terms) -> terms
      {_valid, invalid, {{:line, line}, {:column, col}}} ->
        case String.split(invalid, "\n") do
          [] ->
            raise ParseError, message: "Invalid conf file at line #{line}, column #{col}."
          [context|_] ->
            raise ParseError, message: "Invalid conf file at line #{line}, column #{col}:\n\t#{context}"
        end
    end
  end

  @doc """
  Parse the file at the provided path as a .conf file.
  Returns {:ok, terms} | {:error, reason}
  """
  @spec file(binary) :: {:ok, term} | {:error, term}
  def file(path) do
    case :conform_parse.file(path) do
      terms when is_list(terms) ->
        {:ok, terms}
      {_valid, invalid, {{:line, line}, {:column, col}}} ->
        case String.split(invalid, "\n") do
          [] ->
            {:error, "Invalid conf file at line #{line}, column #{col}."}
          [context|_] ->
            {:error, "Invalid conf file at line #{line}, column #{col}:\n\t#{context}"}
        end
    end
  end

  @doc """
  Parse the provided binary as a .conf file,
  returning either the parsed terms, or raising a ParseError if parsing fails.
  """
  @spec parse!(binary) :: term | no_return
  def parse!(binary) do
    case parse(binary) do
      {:ok, terms}     -> terms
      {:error, reason} -> raise ParseError, message: "#{reason}"
    end
  end

  @doc """
  Parse the provided binary as a .conf file.
  Returns {:ok, terms} | {:error, reason}
  """
  @spec parse(binary) :: {:ok, term} | {:error, term}
  def parse(binary) do
    case :conform_parse.parse(binary) do
      terms when is_list(terms) ->
        {:ok, terms}
      {_valid, invalid, {{:line, line}, {:column, col}}} ->
        case String.split(invalid, "\n") do
          [] ->
            {:error, "Invalid conf at line #{line}, column #{col}."}
          [context|_] ->
            {:error, "Invalid conf at line #{line}, column #{col}:\n\t#{context}"}
        end
    end
  end
end
