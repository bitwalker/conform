defmodule Conform.Utils.Code do
  @moduledoc """
  This module contains utility functions for manipulating,
  transforming, and stringifying code.
  """

  alias Conform.Utils.Code

  # inside supports :none, :fn, :case
  defstruct indent: 1, inside: [:none]

  @space 32

  def stringify(quoted) do
    quoted |> Macro.to_string |> do_stringify("", %Code{})
  end

  # Handle strings. If string contains newlines, convert to heredoc
  defp do_stringify(<<?", rest :: binary>>, acc, %Code{indent: indent} = opts) do
    {string, remainder} = read_string(rest, "\"", opts)
    string = case string |> String.contains?("\n") do
      true  -> to_heredoc(string, indent)
      false -> string
    end
    do_stringify(remainder, acc <> string, opts)
  end
  # Handle commas followed by a space, replace space with newline
  defp do_stringify(<<?,, @space, rest :: binary>>, acc, %Code{indent: indent, inside: [:none]} = opts),
    do: do_stringify(rest, acc <> ",\n#{tabs(indent - 1)}", opts)
  # Handle open bracket (outside of any block), add newline after bracket
  defp do_stringify(<<?[, rest :: binary>>, acc, %Code{indent: indent, inside: [:none]} = opts),
    do: do_stringify(rest, acc <> "[\n#{tabs(indent)}", %{opts | :indent => indent + 1})
  # Handle closing bracket with trailing comma (outside of any block), by putting the bracket
  # on a new line, and starting a new line after it.
  defp do_stringify(<<?], ?,, @space, rest :: binary>>, acc, %Code{indent: indent, inside: [:none]} = opts),
    do: do_stringify(rest, acc <> "\n#{tabs(indent-2)}],\n#{tabs(indent-2)}", %{opts | :indent => indent - 1})
  # Handle closing bracket (outside of any block), by putting the bracket on a new line
  defp do_stringify(<<?], rest :: binary>>, acc, %Code{indent: indent, inside: [:none]} = opts),
    do: do_stringify(rest, acc <> "\n#{tabs(indent - 2)}]", %{opts | :indent => indent - 1})
  # Strip tabs from the input
  defp do_stringify(<<?\t, rest :: binary>>, acc, opts),
    do: do_stringify(rest, acc, opts)
  # If a newline precedes `end`, make sure it's properly indented
  defp do_stringify(<<?\n, "end", rest :: binary>>, acc, %Code{indent: indent, inside: [block|_]} = opts)
    when block in [:fn, :case],
    do: do_stringify("end" <> rest, acc <> "\n#{tabs(indent-3)}", %{opts | :indent => indent - 1})
  # Make sure new lines within a block are properly indented
  defp do_stringify(<<?\n, rest :: binary>>, acc, %Code{indent: indent, inside: [block|_]} = opts)
    when block in [:fn, :case] do
      case end_of_match?(rest) do
        true ->
          do_stringify(rest, acc <> "\n#{tabs(indent - 2)}", %{opts | :indent => indent - 1})
        _ ->
          do_stringify(rest, acc <> "\n#{tabs(indent - 1)}", opts)
      end
  end
  # Strip all other newlines from input
  defp do_stringify(<<?\n, rest :: binary>>, acc, opts),
    do: do_stringify(rest, acc, opts)
  # When we encounter `fn`, update `inside` to show that we are now in a function block
  defp do_stringify(<<?f, ?n, rest :: binary>>, acc, %Code{indent: indent, inside: inside} = opts) do
    case multi_clause?(rest) do
      true ->
        do_stringify(rest, acc <> "fn", %{opts | :indent => indent + 1, :inside => [:fn|inside]})
      false ->
        do_stringify(rest, acc <> "fn", %{opts | :inside => [:fn|inside]})
    end
  end
  # When we encounter `case`, update `inside` to show that we are now in a case block
  defp do_stringify(<<?c, ?a, ?s, ?e, rest :: binary>>, acc, %Code{indent: indent, inside: inside} = opts),
    do: do_stringify(rest, acc <> "case", %{opts | :indent => indent + 1, :inside => [:case|inside]})
  # Strip trailing whitespace from ->
  defp do_stringify(<<?-, ?>, 32, rest :: binary>>, acc, opts),
    do: do_stringify("->" <> rest, acc, opts)
  # Always start function bodies on a new line
  defp do_stringify(<<?-, ?>, ?\n, rest :: binary>>, acc, %Code{indent: indent, inside: [:fn|_]} = opts),
    do: do_stringify(rest, acc <> "->\n#{tabs(indent-1)}", %{opts | :indent => indent + 1})
  # For case statements, only do so if they were on a new line in the original source
  defp do_stringify(<<?-, ?>, ?\n, rest :: binary>>, acc, %Code{indent: indent, inside: [:case|_]} = opts),
    do: do_stringify(rest, acc <> "->\n#{tabs(indent)}", %{opts | :indent => indent + 1})
  defp do_stringify(<<?-, ?>, rest :: binary>>, acc, %Code{indent: indent, inside: [:fn|_]} = opts),
    do: do_stringify(rest, acc <> "->\n#{tabs(indent)}", %{opts | :indent => indent})
  defp do_stringify(<<?-, ?>, rest :: binary>>, acc, %Code{indent: indent, inside: [:case|_]} = opts),
    do: do_stringify(rest, acc <> "->", %{opts | :indent => indent})
  # If `do` is encountered, start a new line
  defp do_stringify(<<?d, ?o, h :: utf8, rest :: binary>>, acc, %Code{indent: indent} = opts)
    when h in [?\n, 32, ?\t],
    do: do_stringify(rest, acc <> "do\n#{tabs(indent)}", %{opts | :indent => indent + 1})
  # If `end` with a trailing comma is encountered, ensure there is a new line inserted
  defp do_stringify(<<?e, ?n, ?d, ?,, next :: utf8, rest :: binary>>, acc, %Code{indent: indent, inside: [:fn|ins]} = opts)
    when next in [@space, ?\n],
    do: do_stringify(rest, acc <> "end,\n#{tabs(indent-2)}", %{opts | :indent => indent - 1, :inside => ins})
  # If `end` is encountered, back out the current indent level, and remove the most recent
  # block from `inside`
  defp do_stringify(<<?e, ?n, ?d, rest :: binary>>, acc, %Code{indent: indent, inside: [:fn|ins]} = opts) do
    acc = replace_indent(acc, indent-2)
    do_stringify(rest, acc <> "end", %{opts | :indent => indent - 1, :inside => ins})
  end
  defp do_stringify(<<?e, ?n, ?d, rest :: binary>>, acc, %Code{indent: indent, inside: [:case|ins]} = opts) do
    acc = replace_indent(acc, indent-2)
    do_stringify(rest, acc <> "end", %{opts | :indent => indent - 1, :inside => ins})
  end
  defp do_stringify(<<leader :: utf8, ?e, ?n, ?d, rest :: binary>>, acc, %Code{indent: indent, inside: [block|ins]} = opts)
    when leader in [@space, ?\n] do
      case block do
        :case ->
          acc = replace_indent(acc, indent-2)
          do_stringify(rest, acc <> "\nend\n", %{opts | :indent => indent - 1, :inside => ins})
        _ ->
          do_stringify(rest, acc <> "\n#{tabs(indent-2)}end", %{opts | :indent => indent - 1, :inside => ins})
      end
  end
  # Strip extra inner whitespace from case blocks
  defp do_stringify(<<@space, @space, rest :: binary>>, acc, %Code{inside: [:case|_]} = opts),
    do: do_stringify(rest, acc, opts)
  # Handle a single character (no special processing)
  defp do_stringify(<<h :: utf8, rest :: binary>>, acc, opts),
    do: do_stringify(rest, <<acc :: binary, h :: utf8>>, opts)
  # When we've handled all characters in the source, return
  defp do_stringify(<<>>, acc, _),
    do: <<acc :: binary, ?\n>>

  # Read in a string value surrounded by quotes, convert nested quotes to their
  # unescaped form, since this string will be converted to a heredoc
  defp read_string(<<?\\, ?", rest :: binary>>, acc, opts),
    do: read_string(rest, <<acc :: binary, ?">>, opts)
  defp read_string(<<?", rest :: binary>>, acc, _),
    do: {<<acc :: binary, ?" >>, rest}
  defp read_string(<<?\\, ?n, rest :: binary>>, acc, %Code{indent: indent} = opts),
    do: read_string(rest, <<acc :: binary, ?\n, tabs(indent) :: binary>>, opts)
  defp read_string(<<h :: utf8, rest :: binary>>, acc, opts),
    do: read_string(rest, <<acc :: binary, h :: utf8>>, opts)

  # Convert the provided string to a heredoc-formatted string.
  # :open and :closed refer to whether the heredoc triple-quotes
  # are open or closed.
  defp to_heredoc(<<?\", rest :: binary>>, indent),
    do: to_heredoc(rest, :open, "\"\"\"\n#{tabs(indent)}")
  defp to_heredoc(bin, indent),
    do: to_heredoc(bin, :open, "\"\"\"\n#{tabs(indent)}")
  defp to_heredoc(<<?\">>, :open, acc),
    do: to_heredoc(<<>>, :closed, <<acc :: binary, ?", ?", ?">>)
  defp to_heredoc(<<?\", rest :: binary>>, :open, acc),
    do: to_heredoc(rest, :open, <<acc :: binary, ?">>)
  defp to_heredoc(<<next :: utf8, rest :: binary>>, :open, acc),
    do: to_heredoc(rest, :open, <<acc :: binary, next :: utf8>>)
  defp to_heredoc(<<>>, :open, acc),
    do: <<acc :: binary, ?", ?", ?">>
  defp to_heredoc(<<>>, :closed, acc),
    do: acc

  # Determine if the end of the current case match is on this line
  defp end_of_match?(bin),                                    do: end_of_match?(bin, false)
  defp end_of_match?(<<>>, result),                           do: result
  defp end_of_match?(<<?\n, _ :: binary>>, result),           do: result
  defp end_of_match?(<<?-, ?>, _ :: binary>>, _),             do: true
  defp end_of_match?(<<?e, ?n, ?d, _ :: binary>>, _),         do: true
  defp end_of_match?(<<_ :: utf8, rest :: binary>>, result),  do: end_of_match?(rest, result)

  # Given a string representing a function, determine if it's a multi clause function
  defp multi_clause?(<<?f, ?n, bin :: binary>>),                 do: multi_clause?(bin, [], 0)
  defp multi_clause?(bin),                                       do: multi_clause?(bin, [], 0)
  defp multi_clause?(<<>>, _, count),                            do: count > 1
  defp multi_clause?(<<?e, ?n, ?d, _ :: binary>>, [], count),    do: count > 1
  defp multi_clause?(<<?-, ?>, rest :: binary>>, [], count),     do: multi_clause?(rest, [], count + 1)
  defp multi_clause?(<<?f, ?n, rest :: binary>>, levels, count), do: multi_clause?(rest, [:fn|levels], count)
  defp multi_clause?(<<?c, ?a, ?s, ?e, rest :: binary>>, levels, count), do: multi_clause?(rest, [:case|levels], count)
  defp multi_clause?(<<?e, ?n, ?d, rest :: binary>>, [_|levels], count), do: multi_clause?(rest, levels, count)
  defp multi_clause?(<<_ :: utf8, rest :: binary>>, levels, count),      do: multi_clause?(rest, levels, count)

  # Replace the trailing indentation in the provided string
  defp replace_indent(bin, indent),      do: replace_indent(bin, byte_size(bin) - 1, indent)
  defp replace_indent(bin, size, indent) do
    case bin do
      <<trimmed :: binary-size(size), trailing :: utf8>> when trailing in [@space, ?\t] ->
        replace_indent(trimmed, size - 1, indent)
      _ ->
        bin <> tabs(indent)
    end
  end

  # Optimize generating tab strings for up to 50 indentation levels
  for x <- 1..50 do
    quoted = quote do
      defp tabs(unquote(x)), do: unquote(String.duplicate("  ", x))
    end
    Module.eval_quoted __MODULE__, quoted, [], __ENV__
  end
  defp tabs(x) when x > 50, do: String.duplicate("  ", x)
  defp tabs(_), do: ""
end