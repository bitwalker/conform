defmodule Conform.Logger do
  @moduledoc false

  def debug(message),   do: log(:debug, [:cyan], message)
  def info(message),    do: log(:info, [:bright, :cyan], "==> #{message}")
  def success(message), do: log(:success, [:bright, :green], "==> #{message}")
  def warn(message) do
    if Application.get_env(:conform, :warnings_as_errors, false) do
      error(message)
    else
      log(:warn, [:yellow], message)
    end
  end
  def error(message) do
    log(:error, [:red], message)
    exit({:shutdown, 1})
  end

  defp log(level, color, message) do
    log_level = Application.get_env(:conform, :verbosity, :normal)
    log(log_level, level, color, message)
  end
  defp log(:verbose, _, color, message),       do: colorize(color, message)
  defp log(:quiet, :error, color, message),    do: colorize(color, message)
  defp log(:quiet, :warn, color, message),     do: colorize(color, message)
  defp log(:quiet, _, _color, _message),       do: :ok
  defp log(:silent, :error, color, message),   do: colorize(color, message)
  defp log(:silent, _, _color, _message),      do: :ok
  defp log(:normal, :debug, _color, _message), do: :ok
  defp log(:normal, _, color, message),        do: colorize(color, message)

  defp colorize(colors, message) do
    IO.puts IO.ANSI.format([colors, message])
  end
end
