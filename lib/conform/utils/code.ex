defmodule Conform.Utils.Code do
  @moduledoc """
  This module provides handy utilities for low-level
  manipulation of Elixir's AST. Currently, it's primary
  purpose is for stringification of schemas for printing
  or writing to disk.
  """

  @doc """
  Takes a schema in quoted form and produces a string
  representation of that schema for printing or writing
  to disk.
  """
  def stringify(schema) do
    # Use an agent to store indentation level
    Agent.start_link(fn -> 0 end, name: __MODULE__)
    reset_indent!()
    # Walk the syntax tree and transform each node into a string
    schema
    |> do_stringify
  end

  defp do_stringify(list) when is_list(list) do
    case list do
      [] -> <<?[, ?]>>
      _  ->
        indent!()
        format_list(list, <<?[>>)
    end
  end
  defp do_stringify(string) when is_binary(string) do
    is_unicode?  = :io_lib.printable_unicode_list(:binary.bin_to_list(string))
    has_newline? = String.contains?(string, "\n")
    cond do
      is_unicode? && has_newline? -> to_heredoc(string)
      :else -> "\"#{string}\""
    end
  end
  defp do_stringify(%Regex{} = regex) do
    "~r/" <> Regex.source(regex) <> "/"
  end
  defp do_stringify(term) do
    "#{inspect term}"
  end

  ##################
  # List Formatting
  #
  # The following is the intended look
  # and feel of the formatting for lists
  # that `stringify` will produce.
  #
  # [
  #   key1: [
  #     key2: [:foo, :bar]
  #   ]
  # ]
  defp format_list([], acc) do
    acc <> "\n" <> tabs(unindent!()) <> "]"
  end
  # 1 or more key/value pair elements
  defp format_list([{key, value}|rest], acc) do
    tuples_required? = not Keyword.keyword?(rest)
    case rest do
      [] ->
        format_list(rest, format_list_item({key, value}, acc))
      _  ->
        format_list(rest, format_list_item({key, value}, acc, tuples_required?: tuples_required?) <> ",")
    end
  end
  # 1 or more of any other element type
  defp format_list([h|t], acc) do
    case t do
      [] -> format_list(t, acc <> "\n" <> tabs(get_indent()) <> "#{inspect(h)}")
      _  -> format_list(t, acc <> "\n" <> tabs(get_indent()) <> "#{inspect(h)}" <> ",")
    end
  end

  defp format_list_item(item, acc, opts \\ [])

  # A list item which is a key/value pair with a function as the value
  defp format_list_item({key, {:fn, _, _} = fndef}, acc, _opts) do
    <<?:, keystr::binary>> = "#{inspect key}"
    acc <> "\n" <> tabs(get_indent()) <> keystr <> ": " <> format_function(fndef)
  end
  # Just a tuple
  defp format_list_item({a, _} = tuple, acc, _opts) when not is_atom(a) do
    acc <> "\n" <> tabs(get_indent()) <> "#{inspect tuple}"
  end
  # A key/value pair list item
  defp format_list_item({key, value}, acc, opts) do
    tuples_required? = Keyword.get(opts, :tuples_required?, false)
    stringified_value = do_stringify(value)
    case "#{inspect key}" do
      <<?:, keystr::binary>> ->
        if tuples_required? do
          acc <> "\n" <> tabs(get_indent()) <> "{:" <> keystr <> ", " <> stringified_value <> "}"
        else
          acc <> "\n" <> tabs(get_indent()) <> keystr <> ": " <> stringified_value
        end
      keystr ->
        if tuples_required? do
          acc <> "\n" <> tabs(get_indent()) <> "{:\"#{keystr}\", " <> stringified_value <> "}"
        else
          acc <> "\n" <> tabs(get_indent()) <> "\"#{keystr}\": " <> stringified_value
        end
    end
  end
  # Any other list item value
  defp format_list_item(val, acc, _opts) do
    acc <> "\n" <> tabs(get_indent()) <> "#{inspect val}"
  end

  #######################
  # Function Formatting
  #
  # The following is what functions
  # are expected to be formatted like
  # in the output that `stringify` produces
  #
  # fn <params> ->
  #   <clause1>
  #   <clause2>
  # end
  #
  # fn
  #   <params1> ->
  #     <clause1>
  #     <clause2>
  #   <params2> ->
  #     <clause3>
  # end
  defp format_function({:fn, _, clauses}) do
    {fn_head, indenter} = case clauses do
      [_]   -> {"fn ", &get_indent/0}
      [_|_] -> {"fn\n#{tabs(indent!())}", &unindent!/0}
    end
    clauses
    |> format_function(fn_head)
    |> String.replace(~r/\n\s+$/, "\n" <> tabs(indenter.()) <> "end")
  end
  defp format_function([clause], acc) do
    acc <> format_function_clause(clause)
  end
  defp format_function([clause|rest], acc) do
    format_function(rest, acc <> format_function_clause(clause))
  end
  defp format_function_clause({:->, opts, [params, body]}) do
    opts     = opts || []
    indent   = Keyword.get(opts, :indent) || indent!()
    unindent = case Keyword.get(opts, :indent) do
      nil -> &unindent!/0
      _   -> fn -> indent - 1 end
    end
    params = params
             |> Enum.map(&format_function_param/1)
             |> Enum.join(", ")
    body   = body
             |> format_function_body
             |> String.split("\n", trim: true)
             |> Enum.join("\n" <> tabs(indent))
    params <> " ->\n" <> tabs(indent) <> body <> "\n" <> tabs(unindent.())
  end
  defp format_function_param({:when, _env, _condition} = clause) do
    Macro.to_string(clause)
  end
  defp format_function_param({:=, _, [pattern, value]}) do
    Macro.to_string(pattern) <> " = " <> Macro.to_string(value)
  end
  defp format_function_param({:in, _, [value, matches]}) do
    Macro.to_string(value) <> " in " <> Macro.to_string(matches)
  end
  defp format_function_param(param) do
    Macro.to_string(param)
  end
  defp format_function_body({:if, _, [condition, body]}) do
    case {Keyword.get(body, :do, nil), Keyword.get(body, :else, nil)} do
      {yep, nil} ->
        """
        if #{Macro.to_string(condition)} do
          #{yep |> format_function_body}
        end
        """
      {yep, nope} ->
        """
        if #{Macro.to_string(condition)} do
          #{yep |> format_function_body}
        else
          #{nope |> format_function_body}
        end
        """
    end
  end
  defp format_function_body({:case, _, [pattern, [do: clauses]]}) do
    case_head = "case #{Macro.to_string(pattern)} do\n  "
    result = clauses
    |> Enum.map(&(put_elem(&1, 1, [indent: 2])))
    |> Enum.map(&format_function_clause/1)
    |> Enum.join
    |> String.replace(~r/\n\s+$/, "\n" <> "end")
    case_head <> result
  end
  defp format_function_body({:__block__, _, body}) do
    body
    |> Enum.map(&Macro.to_string/1)
    |> Enum.join("\n")
  end
  defp format_function_body(body) do
    Macro.to_string(body)
  end

  # Convert the provided string to a heredoc-formatted string.
  # :open and :closed refer to whether the heredoc triple-quotes
  # are open or closed.
  defp to_heredoc(<<?\", rest :: binary>>),
    do: to_heredoc(rest, :open, "\"\"\"\n#{tabs(get_indent())}")
  defp to_heredoc(bin),
    do: to_heredoc(bin, :open, "\"\"\"\n#{tabs(get_indent())}")
  defp to_heredoc(<<?\">>, :open, acc),
    do: to_heredoc(<<>>, :closed, <<acc :: binary, ?", ?", ?">>)
  defp to_heredoc(<<?\", rest :: binary>>, :open, acc),
    do: to_heredoc(rest, :open, <<acc :: binary, ?">>)
  defp to_heredoc(<<next :: utf8, rest :: binary>>, :open, acc),
    do: to_heredoc(rest, :open, <<acc :: binary, next :: utf8>>)
  defp to_heredoc(<<>>, :open, acc) do
    <<acc :: binary, "#{tabs(get_indent())}\"\"\"">>
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.join("\n" <> tabs(get_indent()))
  end
  defp to_heredoc(<<>>, :closed, acc) do
    acc
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.join("\n" <> tabs(get_indent()))
  end

  # Manage indentation state
  defp indent!,       do: set_indent(+1)
  defp unindent!,     do: set_indent(-1)
  defp reset_indent!, do: Agent.update(__MODULE__, fn _ -> 0 end)
  defp get_indent(),  do: Agent.get(__MODULE__, fn i -> i end)
  defp set_indent(0), do: get_indent()
  defp set_indent(x), do: Agent.get_and_update(__MODULE__, &{&1+x, &1+x})

  # Optimize generating tab strings for up to 50 indentation levels
  1..50 |> Enum.reduce(<<32, 32>>, fn x, spaces ->
    quoted = quote do
      defp tabs(unquote(x)), do: unquote(spaces)
    end
    Module.eval_quoted __MODULE__, quoted, [], __ENV__
    <<spaces::binary, 32, 32>>
  end)
  defp tabs(x) when x > 50, do: String.duplicate("  ", x)
  defp tabs(_), do: ""
end
