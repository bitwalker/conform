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
  def read(path), do: path |> String.to_charlist |> :file.consult

  @doc """
  Write a config (in the form of Elixir terms) to disk in
  the required *.config format.
  """
  @spec write(binary, term) :: :ok | {:error, term}
  def write(path, config) do
    bin = :io_lib.fwrite('~tp.~n', [config])
    case :file.write_file(String.to_charlist(path), bin, [encoding: :utf8]) do
      :ok -> :ok
      {:error, reason} -> {:error, :file.format_error(reason)}
    end
  end

  @doc """
  Print a config to the console without applying any formatting
  """
  def print(config) do
    config = Conform.Utils.sort_kwlist(config)
    if IO.ANSI.enabled? do
      colors = [
        number: :yellow,
        atom: :cyan,
        regex: :yellow,
        string: :green
      ]
      IO.inspect(config, width: 0, limit: :infinity, pretty: true, syntax_colors: colors)
    else
      IO.inspect(config, width: 0, limit: :infinity, pretty: true)
    end
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
    |> Conform.Utils.sort_kwlist
    |> Inspect.Algebra.to_doc(%Inspect.Opts{pretty: true, limit: 1000})
    |> Inspect.Algebra.format(80)
  end
end
