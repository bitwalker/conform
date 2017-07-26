defmodule Conform.Conf do
  @moduledoc """
  This module is exposed to schemas for usage in transformations, it
  contains utility functions for fetching configuration information from the current config state.
  """

  @doc """
  Parses a .conf located at the provided path, does some initial
  validation and reformatting, and dumps it into an ETS table for
  further processing. The table identifier is returned, but the
  preferred method for manipulating/querying the conf terms is via
  this module's API.
  """
  @spec from_file(String.t) :: {:error, term} | {:ok, non_neg_integer() | atom()}
  def from_file(path) when is_binary(path) do
    case Conform.Parse.file(path) do
      {:error, _} = err -> err
      {:ok, parsed}     -> from(parsed)
    end
  end

  @doc """
  Parses a .conf from the provided binary, does some initial
  validation and reformatting, and dumps it into an ETS table for
  further processing. The table identifier is returned, but the
  preferred method for manipulating/querying the conf terms is via
  this module's API.
  """
  @spec from_binary(binary) :: {:error, term} | {:ok, non_neg_integer() | atom()}
  def from_binary(conf) when is_binary(conf) do
    case Conform.Parse.parse(conf) do
      {:error, _} = err -> err
      {:ok, parsed}     -> from(parsed)
    end
  end

  @doc false
  def from(conf) do
    table = :ets.new(:conform_query, [:set, keypos: 1])
    for {key, value} <- conf do
      # In order to make sure that module names in key paths are not split,
      # get_key_path rejoins those parts, the result is the actual key we will
      # use in the final config
      proper_key = get_key_path(key)
      :ets.insert(table, {proper_key, value})
    end
    {:ok, table}
  end

  @doc """
  Selects key/value pairs from the conf table which match the provided key exactly,
  or match the provided key+variables exactly. Keys with variables (expressed as `$varname`),
  act as wildcards for that element of the key, so they can match more than a single setting.

  Results are returned in the form of `{key, value}` where key is the full key of the
  setting.

  ## Examples

      iex> table = :ets.new(:test, [:set, keypos: 1])
      ...> :ets.insert(table, {['lager', 'handlers', 'console', 'level'], :info})
      ...> :ets.insert(table, {['lager', 'handlers', 'file', 'error'], '/var/log/error.log'})
      ...> #{__MODULE__}.get(table, "lager.handlers.console.level")
      [{['lager', 'handlers', 'console', 'level'], :info}]
      ...> #{__MODULE__}.get(table, "lager.handlers.$backend.$setting")
      [{['lager', 'handlers', 'console', 'level'], :info},
       {['lager', 'handlers', 'file', 'error'], '/var/log/error.log'}]
  """
  @spec get(non_neg_integer() | atom(), String.t | [charlist]) :: [{[atom], term}] | {:error, term}
  def get(table, key) when is_binary(key), do: get(table, get_key_path(key))
  def get(table, query) when is_list(query) do
    # Execute query
    case wildcard_get(table, query) do
      {:error, _} = err -> err
      results           -> Enum.map(results, fn {key, _vars, value} -> {key, value} end)
    end
  end

  @doc false
  def wildcard_get(table, query) when is_list(query) do
    # Generate query variables for key parts which start with $
    match_spec = query
    |> Enum.with_index
    |> Enum.map(fn {[?$|_], i} -> {:'$#{i+1}', i}; {[?*], i} -> {:'$#{i+1}', i}; {k, _} -> {k, nil} end)
    variables  = match_spec
    |> Enum.filter(fn {_, nil} -> false; _ -> true end)
    |> Enum.map(fn {var, i} -> {{Enum.at(query, i), var}} end)
    match_spec = Enum.map(match_spec, fn {k, _} -> k end)
    :ets.select(table, [{{match_spec, :'$100'}, [], [{{match_spec, variables, :'$100'}}]}])
  end

  @doc """
  Selects all keys which match the provided fuzzy search.

  ## Examples

      iex> table = :ets.new(:test, [:set, keypos: 1])
      ...> :ets.insert(table, {['lager', 'handlers', 'console', 'level'], :info})
      ...> :ets.insert(table, {['lager', 'handlers', 'file', 'error'], '/var/log/error.log'})
      ...> #{__MODULE__}.fuzzy_get(table, "lager.handlers.*")
      [{['lager', 'handlers', 'console', 'level'], :info}]
      ...> #{__MODULE__}.fuzzy_get(table, "lager.handlers.$backend")
      [{['lager', 'handlers', 'console', 'level'], :info},
      {['lager', 'handlers', 'file', 'error'], '/var/log/error.log'}]

  """
  def fuzzy_get(table, key) when is_binary(key), do: fuzzy_get(table, get_key_path(key))
  def fuzzy_get(table, query) when is_list(query) do
    # Bind variables elements of the query to ETS match variables
    match_spec = query
    |> Enum.with_index
    |> Enum.map(fn {[?$|_], i} -> {:'$#{i+1}', i}; {k, _} -> {k, nil} end)
    variables  = match_spec
    |> Enum.filter(fn {_, nil} -> false; _ -> true end)
    |> Enum.map(fn {var, i} -> {{Enum.at(query, i), var}} end)

    # Generate match spec which behaves like matching on the head of a list,
    # e.g. [el1, el2 | rest]
    {match_spec_wild, wild?} = case List.last(match_spec) do
                    {'*', _} ->
                      {head, [{k,_}|_]} = Enum.split(match_spec, length(match_spec) - 2)
                      list = head ++ [{:|, [], [k, :'$99']}]
                      {qp, _} = Code.eval_quoted(list)
                      {qp, true}
                    _ ->
                      {match_spec, false}
                  end
    # Get list of variables to select, paired with their original names
    # Destruct with_index tuple
    match_spec_final = strip_index_for_query(match_spec_wild, [])
    match_body = strip_index_for_query(match_spec, [])
    # Prepare query
    select_expr = cond do
      wild? ->
        [{{match_spec_final, :'$100'}, [], [{{match_body, :'$99', variables, :'$100'}}]}]
      :else ->
        [{{match_spec_final, :'$100'}, [], [{{match_body, variables, :'$100'}}]}]
    end
    :ets.select(table, select_expr)
    |> Enum.map(fn
      {_key, _vars, _val} = result ->
        result
      {key, wildcard, _vars, val} ->
        {head, _} = Enum.split(key, length(key) - 1)
        {head++wildcard, val}
    end)
  end

  defp strip_index_for_query([], acc),     do: acc
  defp strip_index_for_query([{k,_}|t], acc) do
    strip_index_for_query(t, acc ++ [k])
  end
  defp strip_index_for_query([k|t], acc) when is_list(t) do
    strip_index_for_query(t, acc ++ [k])
  end
  defp strip_index_for_query([k|t], acc) do
    acc ++ [k|t]
  end

  @doc """
  Selects key/value pairs from the conf table which match the provided key, or
  are a child of the provided key. Keys can contain variables expressed as `$varname`,
  which act as wildcards for that element of the key.

  Results are returned in the form of `{key, value}` where key is the full key of the
  setting.

  ## Examples

      iex> table = :ets.new(:test, [:set, keypos: 1])
      ...> :ets.insert(table, {['lager', 'handlers', 'console', 'level'], :info})
      ...> :ets.insert(table, {['lager', 'handlers', 'file', 'error'], '/var/log/error.log'})
      ...> #{__MODULE__}.find(table, "lager.handlers.$backend.level")
      [{['lager', 'handlers', 'console', 'level'], :info}]
      ...> #{__MODULE__}.get(table, "lager.handlers.$backend")
      [{['lager', 'handlers', 'console', 'level'], :info},
       {['lager', 'handlers', 'file', 'error'], '/var/log/error.log'}]
  """
  @spec find(non_neg_integer() | atom(), String.t | [charlist]) :: [{[atom], term}]
  def find(table, key) when is_binary(key), do: get_matches(table, get_key_path(key))
  def find(table, key) when is_list(key),   do: get_matches(table, key)

  @doc """
  Removes any key/value pairs from the conf table which match the provided key or
  are a child of the provided key.
  """
  @spec remove(non_neg_integer() | atom(), String.t | [charlist]) :: :ok
  def remove(table, key) when is_binary(key), do: remove(table, get_key_path(key))
  def remove(table, key) when is_list(key) do
    case get_matches(table, key) do
      []      -> :ok
      matches -> Enum.each(matches, fn match -> :ets.delete_object(table, match) end)
    end
  end

  @doc """
  Given a string or atom of the form `some.path.to.a.setting`, it breaks it into a list of it's component parts,
  ensuring that embedded module names are preserved, and that the `Elixir` prefix is added if missing and applicable:

  ## Example

      "myapp.Some.Module.setting" => ['myapp', 'Elixir.Some.Module', 'setting']
  """
  def get_key_path(key)

  def get_key_path(key) when is_atom(key) do
    key
    |> Atom.to_string
    |> get_key_path
  end
  def get_key_path(key) when is_binary(key) do
    joined =
      case String.split(key, ".", trim: true) do
        [_app, "Elixir" | _] = parts ->
          # This is an elixir module with the Elixir prefix
          join_module_parts(parts)
        [app, <<first_char::utf8, _::binary>> = mod | rest] when first_char in ?A..?Z ->
          # This is an elixir module without the Elixir prefix
          join_module_parts([app, "Elixir", mod | rest])
        parts ->
          join_module_parts(parts)
      end
    Enum.map(joined, &String.to_charlist/1)
  end
  def get_key_path(key) when is_list(key) do
    joined =
      case Enum.map(key, &List.to_string/1) do
        [_app, "Elixir" | _] = parts ->
          join_module_parts(parts)
        [app, <<first_char::utf8, _::binary>> = mod | rest] when first_char in ?A..?Z ->
          join_module_parts([app, "Elixir", mod | rest])
        parts ->
          join_module_parts(parts)
      end
    Enum.map(joined, &String.to_charlist/1)
  end

  # Handles joining module name parts contained in an list of key parts
  # into a single part, preserving the rest of the list, i.e.:
  #   ['myapp', 'Some', 'Module', 'setting'] => ['myapp', 'Some.Module', 'setting']
  defp join_module_parts(parts) when is_list(parts) do
    join_module_parts(parts, [], <<>>) |> Enum.reverse
  end
  defp join_module_parts([], acc, <<>>), do: acc
  defp join_module_parts([], acc, name), do: [name|acc]
  defp join_module_parts([<<c::utf8, _::binary>> = h|t], acc, <<>>) when c in ?A..?Z do
    join_module_parts(t, acc, h)
  end
  defp join_module_parts([<<c::utf8, _::binary>> = h|t], acc, name) when c in ?A..?Z do
    join_module_parts(t, acc, name <> "." <> h)
  end
  defp join_module_parts([h|t], acc, <<>>), do: join_module_parts(t, [h|acc], <<>>)
  defp join_module_parts([h|t], acc, name), do: join_module_parts(t, [h, name|acc], <<>>)

  # Given a key query and an ETS table identifier, execute a query for objects which
  # have keys which match that query. For example:
  #
  # Call: get_matches(table, ['lager', 'handlers', '$backend'])
  #
  # ETS table contents:
  #  [{['lager', 'handlers', 'console', 'level'], 'info'},
  #   {['myapp', 'some', 'important', 'setting'], '127.0.0.1:80, 127.0.0.2:81'},
  #   {['lager', 'handlers', 'file', 'error'], '/var/log/error.log'},
  #   {['lager', 'handlers', 'file', 'info'], '/var/log/console.log'},
  #   {['myapp', 'MyModule.Blah', 'foo'], 'bar'}]
  #
  # Results:
  # [{['lager', 'handlers', 'console', 'level'], 'info'},
  #  {['lager', 'handlers', 'file', 'error'], '/var/log/error.log'},
  #  {['lager', 'handlers', 'file', 'info'], '/var/log/console.log'}]
  defp get_matches(table, query) do
    case :ets.select(table, build_match_expr(query)) do
      {:error, _} = err -> err
      results -> Enum.map(results, fn {variables, key, child_key, value} ->
        proper_key = Enum.map(key ++ child_key, fn
          [?$|_] = var ->
            {_, key_part} = List.keyfind(variables, var, 0)
            key_part
          key_part -> key_part
        end)
        {proper_key, value}
      end)
    end
  end

  # Converts a key into a match expression for that key,
  # where matches are the key + any children of that key.
  defp build_match_expr(key) do
    definition = build_match_fun(key)
    {fun, _}   = Code.eval_quoted(definition)
    :ets.fun2ms(fun)
  end

  # Constructs a quoted function definition which matches the provided ETS key
  # The function it builds is effectively the following, with the assumption that
  # `key` is ['lager', 'handlers', '$backend']:
  #
  #   fn {['lager', 'handlers', backend | rest], value} when length(rest) >= 0 ->
  #     {[{'$backend', backend}], ['lager', 'handlers', '$backend'], rest, value}
  #   end
  defp build_match_fun(key) do
    key_parts  = key
                 |> Enum.with_index
                 |> Enum.map(fn {[?$|name], i} -> {{List.to_atom(name), [], Elixir}, i}; {k, _} -> {k, nil} end)
    variables  = key_parts
                 |> Enum.filter(fn {_, nil} -> false; _ -> true end)
                 |> Enum.map(fn {var, i} -> {Enum.at(key, i), var} end)
    key_parts  = Enum.map(key_parts, fn {part, _} -> part end)
    last_part  = List.last(key_parts)
    key_parts  = Enum.take(key_parts, Enum.count(key_parts) - 1)
    {:fn, [], [{:->, [],
      [
        [{:when, [],
          #args, basically fn {[key_parts | rest], value} ->
          [{key_parts ++ [{:|, [], [last_part, {:rest, [], Elixir}]}], {:value, [], Elixir}},
           {:>=, [context: Elixir, import: Kernel],
                [{:length, [context: Elixir, import: Kernel],
                [{:rest, [], Elixir}]}, 0]}]}],
        #body
        {:{}, [],
          [variables, key, {:rest, [], Elixir}, {:value, [], Elixir}]
        }
      ]
    }]}
  end
end
