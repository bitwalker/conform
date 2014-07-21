defmodule Conform.Utils.Code do
  @moduledoc """
  This module contains utility functions for manipulating,
  transforming, and stringifying code.
  """

  alias Conform.Utils.Code

  # inside supports :none, :fn, :case
  defstruct indent: 1, inside: [:none]

  def stringify(quoted) do
    quoted |> Macro.to_string |> do_stringify("", %Code{})
  end

  # Add inside: :fn, and inside: :case options, so that we can handle
  # indentation of brackets differently when inside those blocks

  #defp do_stringify("[mappings: " <> rest, acc, indent: indent) do
    #tabs = String.duplicate("\t", indent)
    #do_stringify(rest, "[\n#{tabs}mappings: ", indent: indent + 1)
  #end
  defp do_stringify(<<?", rest :: binary>>, acc, %Code{indent: indent} = opts) do
    {string, remainder} = read_string(rest, "\"", opts)
    string = case string |> String.contains?("\n") do
      true ->
        tabs = String.duplicate("\t", indent - 1)
        string
        |> String.reverse
        |> String.replace("\"", "\"\"\"", global: false)
        |> String.reverse
        |> String.replace("\"", "\"\"\"\n\t#{tabs}", global: false)
      false ->
        string
    end
    do_stringify(remainder, acc <> string, opts)
  end
  defp do_stringify(", " <> rest, acc, %Code{indent: indent, inside: [:none]} = opts) do
    do_stringify(rest, acc <> ",\n#{tabs(indent - 1)}", opts)
  end
  defp do_stringify(<<?[, rest :: binary>>, acc, %Code{indent: indent, inside: [:none]} = opts) do
    do_stringify(rest, acc <> "[\n#{tabs(indent)}", %{opts | :indent => indent + 1})
  end
  defp do_stringify("], " <> rest, acc, %Code{indent: indent, inside: [:none]} = opts) do
    do_stringify(rest, acc <> "\n#{tabs(indent-2)}],\n#{tabs(indent-2)}", %{opts | :indent => indent - 1})
  end
  defp do_stringify(<<?], rest :: binary>>, acc, %Code{indent: indent, inside: [:none]} = opts) do
    do_stringify(rest, acc <> "\n#{tabs(indent - 2)}]", %{opts | :indent => indent - 1})
  end
  defp do_stringify(<<?\t, rest :: binary>>, acc, opts) do
    do_stringify(rest, acc, opts)
  end
  defp do_stringify(<<?\n, "end", rest :: binary>>, acc, %Code{indent: indent, inside: [:case|_]} = opts) do
    do_stringify("end" <> rest, acc <> "\n#{tabs(indent-3)}", %{opts | :indent => indent - 1})
  end
  defp do_stringify(<<?\n, rest :: binary>>, acc, %Code{indent: indent, inside: [:case|_]} = opts) do
    do_stringify(rest, acc <> "\n#{tabs(indent - 2)}", %{opts | :indent => indent - 1})
  end
  defp do_stringify(<<?\n, rest :: binary>>, acc, opts) do
    do_stringify(rest, acc, opts)
  end
  defp do_stringify("fn" <> rest, acc, %Code{inside: inside} = opts) do
    do_stringify(rest, acc <> "fn", %{opts | :inside => [:fn|inside]})
  end
  defp do_stringify("case" <> rest, acc, %Code{inside: inside} = opts) do
    do_stringify(rest, acc <> "case", %{opts | :inside => [:case|inside]})
  end
  defp do_stringify(<<?-, ?>, 32, rest :: binary>>, acc, opts) do
    # Strip trailing whitespace from ->
    do_stringify("->" <> rest, acc, opts)
  end
  defp do_stringify(<<?-, ?>, rest :: binary>>, acc, %Code{indent: indent, inside: [:fn|_]} = opts) do
    do_stringify(rest, acc <> "->\n#{tabs(indent)}", %{opts | :indent => indent + 1})
  end
  defp do_stringify(<<?-, ?>, ?\n, rest :: binary>>, acc, %Code{indent: indent, inside: [:case|_]} = opts) do
    do_stringify(rest, acc <> "->\n#{tabs(indent)}", %{opts | :indent => indent + 1})
  end
  defp do_stringify(<<?-, ?>, rest :: binary>>, acc, %Code{indent: indent, inside: [:case|_]} = opts) do
    do_stringify(rest, acc <> "->", %{opts | :indent => indent})
  end
  defp do_stringify(<<?d, ?o, ?\n, rest :: binary>>, acc, %Code{indent: indent} = opts) do
    do_stringify(rest, acc <> "do\n#{tabs(indent)}", %{opts | :indent => indent + 1})
  end
  defp do_stringify(<<?d, ?o, 32, rest :: binary>>, acc, %Code{indent: indent} = opts) do
    do_stringify(rest, acc <> "do\n#{tabs(indent)}", %{opts | :indent => indent + 1})
  end
  defp do_stringify("end" <> rest, acc, %Code{indent: indent, inside: [:case|ins]} = opts) do
    do_stringify(rest, acc <> "end", %{opts | :indent => indent - 1, :inside => ins})
  end
  defp do_stringify(" end" <> rest, acc, %Code{indent: indent, inside: [:case|ins]} = opts) do
    do_stringify(rest, acc <> "\n#{tabs(indent-2)}end\n", %{opts | :indent => indent - 1, :inside => ins})
  end
  defp do_stringify(" end" <> rest, acc, %Code{indent: indent, inside: [:fn|ins]} = opts) do
    do_stringify(rest, acc <> "\n#{tabs(indent-2)}end", %{opts | :indent => indent - 1, :inside => ins})
  end
  defp do_stringify("  " <> rest, acc, %Code{inside: [:case|_]} = opts) do
    # Strip extra inner whitespace from case blocks
    do_stringify(rest, acc, opts)
  end
  defp do_stringify(<<h :: utf8, rest :: binary>>, acc, opts) do
    do_stringify(rest, <<acc :: binary, h :: utf8>>, opts)
  end
  defp do_stringify(<<>>, acc, _), do: acc

  defp read_string(<<?", rest :: binary>>, acc, _) do
    {<<acc :: binary, ?" >>, rest}
  end
  defp read_string(<<?\\, ?n, rest :: binary>>, acc, %Code{indent: indent} = opts) do
    read_string(rest, <<acc :: binary, ?\n, tabs(indent) :: binary>>, opts)
  end
  defp read_string(<<h :: utf8, rest :: binary>>, acc, opts) do
    read_string(rest, <<acc :: binary, h :: utf8>>, opts)
  end

  defp tabs(x) when x > 0, do: String.duplicate("\t", x)
  defp tabs(_), do: ""
end