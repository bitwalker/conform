defmodule Conform.Config do
  @moduledoc """
  This module is responsible for reading and writing *.config files
  """

  @doc """
  Read an app.config/sys.config from the provided path.
  Returns the config as Elixir terms.
  """
  @spec read(binary) :: [term]
  def read(path), do: path |> List.from_char_data! |> :file.consult

  @doc """
  Write a config (in the form of Elixir terms) to disk in
  the required *.config format.
  """
  @spec write(binary, term) :: :ok | {:error, term}
  def write(path, config) do
    '#{path}' |> :file.write_file(:io_lib.fwrite('~p.\n', [config]))
  end

end