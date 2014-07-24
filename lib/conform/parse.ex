defmodule Conform.Parse do
  @moduledoc """
  This module is responsible for parsing *.conf files
  """

  @doc """
  Parse the .conf file at the provided path
  """
  @spec file(binary) :: term
  def file(path), do: path |> :conf_parse.file

  @doc """
  Parse the provided binary as a .conf file
  """
  @spec parse(binary) :: term
  def parse(binary), do: :conf_parse.parse(binary)
end