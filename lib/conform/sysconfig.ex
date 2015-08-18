defmodule Conform.SysConfig do
  @moduledoc """
  This module is responsible for reading and writing,
  and manipulating *.config files
  """

  @doc """
  Read an app.config/sys.config from the provided path.
  Returns the config as Elixir terms.
  """
  @spec read(binary) :: [term]
  def read(path), do: path |> String.to_char_list |> :file.consult

  @doc """
  Write a config (in the form of Elixir terms) to disk in
  the required *.config format.
  """
  @spec write(binary, term) :: :ok | {:error, term}
  def write(path, config) do
    case File.write!(path, :io_lib.fwrite('~p.\n', [config])) do
      :ok -> :ok
      {:error, reason} -> {:error, :file.format_error(reason)}
    end
  end

  @doc """
  Print a config to the console with pretty formatting
  """
  def pprint(config) do
    config
    |> prettify
    |> IO.puts
  end

  @doc """
  Print a config to the console without applying any formatting
  """
  def print(config) do
    IO.inspect(config)
  end

  @doc """
  Merge two configs together to produce a new unified config.
  The second argument represents the config with the highest precedence
  in the case of conflicts.
  """
  @spec merge(Keyword.t, Keyword.t) :: Keyword.t
  defdelegate merge(config1, config2), to: Conform.Utils

  @doc """
  Apply pretty formatting to a config
  """
  def prettify(config) do
    config
    |> Inspect.Algebra.to_doc(%Inspect.Opts{pretty: true, limit: 1000})
    |> Inspect.Algebra.format(80)
  end

end
