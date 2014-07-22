defmodule Conform.Utils.Code do
  @moduledoc """
  This module contains utility functions for manipulating,
  transforming, and stringifying code.
  """

  @space 32

  # For modules, just use Macro.to_string for now
  def stringify({:defmodule, _, _} = quoted), do: quoted |> Macro.to_string
  # Datastructures are what we care about most
  def stringify(quoted) do
    # Use an agent to store indentation level
    Agent.start_link(fn -> 0 end, name: __MODULE__)
    reset_indent!
    # :inside is used to track the stack of blocks we are currently in
    # by default we start inside no block
    quoted |> Macro.to_string |> do_stringify("", inside: [:none])
  end

  # Handle strings. If string contains newlines, convert to heredoc
  defp do_stringify(<<?", rest :: binary>>, acc, opts) do
    {string, remainder} = read_string(rest, "\"")
    string = case string |> String.contains?("\n") do
      true  -> to_heredoc(string)
      false -> string
    end
    do_stringify(remainder, acc <> string, opts)
  end
  defp do_stringify(<<?[, rest :: binary>>, acc, [inside: [:case|_]] = opts) do
    do_stringify(rest, acc <> "[", opts)
  end
  defp do_stringify(<<?[, rest::binary>>, acc, opts) do
    indent = indent!
    do_stringify(<<tabs(indent)::binary, rest::binary>>, acc <> "[\n", opts)
  end
  defp do_stringify(<<"], ", rest :: binary>>, acc, opts) do
    do_stringify(<<"],", rest::binary>>, acc, opts)
  end
  defp do_stringify(<<"],", rest :: binary>>, acc, opts) do
    indent = unindent!
    do_stringify(<<tabs(indent)::binary, rest::binary>>, acc <> "\n#{tabs(indent)}],\n", opts)
  end
  defp do_stringify(<<?], ?\n, rest :: binary>>, acc, opts) do
    do_stringify(<<?], rest::binary>>, acc, opts)
  end
  defp do_stringify(<<?], rest :: binary>>, acc, [inside: [:case|_]] = opts) do
    do_stringify(rest, <<acc::binary, ?\]>>, opts)
  end
  defp do_stringify(<<?], rest :: binary>>, acc, opts) do
    indent = unindent!
    do_stringify(<<tabs(indent)::binary, rest::binary>>, acc <> "\n#{tabs(indent)}]", opts)
  end
  defp do_stringify(<<"fn", rest :: binary>>, acc, [inside: inside]) do
    case multi_clause?(rest) do
      true ->
        indent = get_indent
        do_stringify(<<tabs(indent)::binary, rest::binary>>, <<acc::binary, "fn">>, inside: [:fn|inside])
      false ->
        do_stringify(rest, acc <> "fn", inside: [:fn|inside])
    end
  end
  defp do_stringify(<<"case", rest :: binary>>, acc, [inside: inside]) do
    {case_def, remainder} = read_def(rest, "case")
    do_stringify(remainder, <<acc::binary, case_def::binary>>, inside: [:case|inside])
  end
  defp do_stringify(<<"->", rest :: binary>>, acc, opts) do
    do_stringify(rest, acc <> "->", opts)
  end
  defp do_stringify(<<"do", next :: utf8, rest :: binary>>, acc, opts)
    when next in [?\n, @space, ?\t] do
      do_stringify(<<tabs(get_indent)::binary, rest::binary>>, acc <> "do\n", opts)
  end
  defp do_stringify(<<"end,", next :: utf8, rest :: binary>>, acc, [inside: [:fn|ins]])
    when next in [@space, ?\n] do
      do_stringify(<<tabs(get_indent)::binary, rest::binary>>, acc <> "end,\n", inside: ins)
  end
  defp do_stringify(<<"end", rest :: binary>>, acc, [inside: [_|ins]]) do
    indent = get_indent
    do_stringify(<<tabs(indent)::binary, rest::binary>>, acc <> "end", inside: ins)
  end
  defp do_stringify(<<?\n, rest :: binary>>, acc, [inside: [block|_]] = opts)
    when block in [:none] == false do
      indent = get_indent
      do_stringify(<<tabs(indent)::binary, rest::binary>>, <<acc::binary, ?\n>>, opts)
  end
  defp do_stringify(<<"defmodule", rest::binary>>, acc, [inside: inside]) do
    {moduledef, remainder} = read_moduledef(rest, "defmodule")
    do_stringify(remainder, <<acc::binary, moduledef::binary>>, inside: [:defmodule|inside])
  end
  defp do_stringify(<<"def", next::utf8, rest::binary>>, acc, [inside: inside])
    when next in [@space, ?\n, ?\t, ?\(] do
      indent!
      {fndef, remainder} = read_def(<<?\(, rest::binary>>, "def")
      do_stringify(remainder, <<acc::binary, fndef::binary>>, inside: [:def|inside])
  end
  defp do_stringify(<<?,, @space, rest :: binary>>, acc, [inside: [:none]] = opts) do
    do_stringify(<<tabs(get_indent)::binary, rest::binary>>, <<acc::binary, ?,, ?\n>>, opts)
  end
  defp do_stringify(<<?,, rest :: binary>>, acc, [inside: [:none]] = opts) do
    do_stringify(rest, <<acc::binary, ?,, ?\n>>, opts)
  end
  defp do_stringify(<<h :: utf8, rest :: binary>>, acc, opts),
    do: do_stringify(rest, <<acc :: binary, h :: utf8>>, opts)
  # When we've handled all characters in the source, return
  defp do_stringify(<<>>, acc, _),
    do: <<acc :: binary, ?\n>>

  # Read in a string value surrounded by quotes, convert nested quotes to their
  # unescaped form, since this string will be converted to a heredoc
  defp read_string(<<?\\, ?", rest :: binary>>, acc),
    do: read_string(rest, <<acc :: binary, ?">>)
  defp read_string(<<?", rest :: binary>>, acc),
    do: {<<acc :: binary, ?" >>, rest}
  defp read_string(<<?\\, ?n, rest :: binary>>, acc),
    do: read_string(rest, <<acc :: binary, ?\n, tabs(get_indent) :: binary>>)
  defp read_string(<<h :: utf8, rest :: binary>>, acc),
    do: read_string(rest, <<acc :: binary, h :: utf8>>)

  # Read in a module definition
  defp read_moduledef(<<?\(, rest :: binary>>, acc),
    do: read_moduledef(rest, <<acc::binary, @space>>)
  defp read_moduledef(<<?\), rest :: binary>>, acc),
    do: {acc, rest}
  defp read_moduledef(<<h::utf8, rest::binary>>, acc),
    do: read_moduledef(rest, <<acc::binary, h::utf8>>)

  # Read in a function definition
  defp read_def(<<?\(, rest :: binary>>, acc),
    do: read_def(rest, :open, <<acc :: binary, @space>>)
  defp read_def(<<?\(, rest :: binary>>, :open, acc),
    do: read_def(rest, :open, <<acc :: binary, ?\(>>)
  defp read_def(<<?\), @space, rest :: binary>>, :open, acc),
    do: {<<acc::binary, @space>>, rest}
  defp read_def(<<?\), ?,, rest :: binary>>, :open, acc),
    do: {<<acc::binary, ?\), ?,>>, rest}
  defp read_def(<<h::utf8, rest::binary>>, status, acc),
    do: read_def(rest, status, <<acc::binary, h::utf8>>)

  # Convert the provided string to a heredoc-formatted string.
  # :open and :closed refer to whether the heredoc triple-quotes
  # are open or closed.
  defp to_heredoc(<<?\", rest :: binary>>),
    do: to_heredoc(rest, :open, "\"\"\"\n#{tabs(get_indent)}")
  defp to_heredoc(bin),
    do: to_heredoc(bin, :open, "\"\"\"\n#{tabs(get_indent)}")
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

  # Given a string representing a function, determine if it's a multi clause function
  defp multi_clause?(<<"fn", bin :: binary>>),                      do: multi_clause?(bin, [], 0)
  defp multi_clause?(bin),                                          do: multi_clause?(bin, [], 0)
  defp multi_clause?(<<>>, _, count),                               do: count > 1
  defp multi_clause?(<<"end", _ :: binary>>, [], count),            do: count > 1
  defp multi_clause?(<<"->", rest :: binary>>, [], count),          do: multi_clause?(rest, [], count + 1)
  defp multi_clause?(<<"fn", rest :: binary>>, levels, count),      do: multi_clause?(rest, [:fn|levels], count)
  defp multi_clause?(<<"case", rest :: binary>>, levels, count),    do: multi_clause?(rest, [:case|levels], count)
  defp multi_clause?(<<"end", rest :: binary>>, [_|levels], count), do: multi_clause?(rest, levels, count)
  defp multi_clause?(<<_ :: utf8, rest :: binary>>, levels, count), do: multi_clause?(rest, levels, count)

  # Manage indentation state
  defp indent!,       do: set_indent(+1)
  defp unindent!,     do: set_indent(-1)
  defp reset_indent!, do: Agent.update(__MODULE__, fn _ -> 0 end)
  defp get_indent,    do: Agent.get(__MODULE__, fn i -> i end)
  defp set_indent(0), do: get_indent
  defp set_indent(x), do: Agent.get_and_update(__MODULE__, fn i -> {i+x, i+x} end)

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