defmodule Conform.Utils do
  @moduledoc false

  @doc """
  Recursively merges two keyword lists. Values themselves are also merged (depending on type),
  such that the resulting keyword list is a true merge of the second keyword list over the first.

  ## Examples

      iex> old = [one: [one_sub: [a: 1, b: 2]], two: {1, "foo", :bar}, three: 'just a charlist', four: [1, 2, 3]]
      ...> new = [one: [one_sub: [a: 2, c: 1]], two: {1, "foo", :baz, :qux}, three: 'a new charlist', four: [1, 2, 4, 6]]
      ...> #{__MODULE__}.merge(old, new)
      [one: [one_sub: [a: 2, b: 2, c: 1]], two: {1, "foo", :baz, :qux}, three: 'a new charlist', four: [1, 2, 4, 6]]
  """
  def merge(old, new) when is_list(old) and is_list(new),
    do: merge(old, new, [])

  defp merge([{_old_key, old_value} = h | t], new, acc) when is_tuple(h) do
    case :lists.keytake(elem(h, 0), 1, new) do
      {:value, {new_key, new_value}, rest} ->
        # Value is present in new, so merge the value
        merged = merge_term(old_value, new_value)
        merge(t, rest, [{new_key, merged}|acc])
      false ->
        # Value doesn't exist in new, so add it
        merge(t, new, [h|acc])
    end
  end
  defp merge([], new, acc) do
    Enum.reverse(acc, new)
  end

  defp merge_term([], new) when is_list(new), do: new
  defp merge_term(old, []) when is_list(old), do: old
  defp merge_term(old, old), do: old
  defp merge_term([oh|_]=old, [nh|_]=new) do
    cond do
      :io_lib.printable_unicode_list(old) && :io_lib.printable_unicode_list(new) ->
        new
      Keyword.keyword?(old) && Keyword.keyword?(new) ->
        Keyword.merge(old, new, fn  _key, old_val, new_val ->
          merge_term(old_val, new_val)
        end)
        |> Enum.sort_by(fn {k, _} -> k end)
      is_list(oh) and is_list(nh) ->
        # Nested lists, we can't safely merge these so use the new one
        new
      :else ->
        new
    end
  end

  defp merge_term(old, new) when is_tuple(old) and is_tuple(new) do
    merged = old
    |> Tuple.to_list
    |> Enum.with_index
    |> Enum.reduce([], fn
        {[], idx}, acc ->
          [elem(new, idx)|acc]
        {val, idx}, acc when is_list(val) ->
          case :io_lib.char_list(val) do
            true ->
              [elem(new, idx) | acc]
            false ->
              merged = merge_term(val, elem(new, idx))
              [merged | acc]
          end
        {val, idx}, acc when is_tuple(val) ->
          [merge_term(val, elem(new, idx)) | acc]
        {val, idx}, acc ->
          [(elem(new, idx) || val) | acc]
       end)
    |> Enum.reverse

    merged_count = Enum.count(merged)
    extra_count  = :erlang.size(new) - merged_count

    case extra_count do
      0 -> List.to_tuple(merged)
      _ ->
        extra = new
          |> Tuple.to_list
          |> Enum.slice(merged_count, extra_count)
        List.to_tuple(merged ++ extra)
    end
  end

  defp merge_term(old, nil),  do: old
  defp merge_term(_old, new), do: new


  @doc """
  Recursively sorts a keyword list such that keys are in ascending alphabetical order

  ## Example

      iex> kwlist = [a: 1, c: 2, b: 3, d: [z: 99, w: 50, x: [a_2: 1, a_1: 2]]]
      ...> #{__MODULE__}.sort_kwlist(kwlist)
      [a: 1, b: 3, c: 2, d: [w: 50, x: [a_1: 2, a_2: 1], z: 99]]
  """
  def sort_kwlist(list) when is_list(list) do
    case Keyword.keyword?(list) do
      true  ->
        do_sort_kwlist(list, [])
        |> Enum.sort_by(fn {k, _} -> k end)
      false -> list
    end
  end
  def sort_kwlist(val), do: val

  defp do_sort_kwlist([{k, v}|t], acc) when is_list(v) do
    result = sort_kwlist(v)
    do_sort_kwlist(t, [{k, result} | acc])
  end
  defp do_sort_kwlist([{k, v}|t], acc), do: do_sort_kwlist(t, [{k, v} | acc])
  defp do_sort_kwlist([], acc), do: acc

  @doc """
  Loads all modules that extend a given module in the current code path.
  """
  @spec load_plugins_of(atom()) :: [] | [atom]
  def load_plugins_of(type) when is_atom(type) do
    type |> available_modules |> Enum.reduce([], &load_plugin/2)
  end

  defp load_plugin(module, modules) do
    if Code.ensure_loaded?(module), do: [module | modules], else: modules
  end

  defp available_modules(plugin_type) do
    :code.all_loaded
    |> Stream.map(fn {module, _path} ->
      try do
        {module, get_in(module.module_info, [:attributes, :behaviour])}
      rescue
        _ ->
          {nil, []}
      end
    end)
    |> Stream.filter(fn {_module, behaviours} -> is_list(behaviours) && plugin_type in behaviours end)
    |> Enum.map(fn {module, _} -> module end)
  end

  @doc """
  Convert a list of results from the conf ETS table (key_path/value tuples)
  into a tree in the form of nested keyword lists. An example:

  - If we have a key of ['lager', 'handlers']
  - And given the following results from Conform.Conf.find for that key:

      [{['lager', 'handlers', 'console', 'level'], :info},
       {['lager', 'handlers', 'file', 'info'], '/var/log/info.log'},
       {['lager', 'handlers', 'file', 'error'], '/var/log/error.log'}]

   - The following tree would be produced

      [console: [level: :info],
       file: [info: '/var/log/info.log', error: '/var/log/error.log']]]]
  """
  @spec results_to_tree([{[charlist], term}], [charlist] | nil) :: Keyword.t
  def results_to_tree(selected, key \\ []) do
    Enum.reduce(selected, [], fn {key_path, v}, acc ->
      key_path = Enum.map(key_path -- key, &List.to_atom/1)
      {_, acc} = Enum.reduce(key_path, {[], acc}, fn
        k, {[], acc} ->
          case get_in(acc, [k]) do
            kw when is_list(kw) -> {[k], acc}
            _ -> {[k], put_in(acc, [k], [])}
          end
        k, {ps, acc} ->
          case get_in(acc, ps++[k]) do
            kw when is_list(kw) -> {ps++[k], acc}
            _ -> {ps++[k], put_in(acc, ps++[k], [])}
          end
      end)
      put_in(acc, key_path, v)
    end)
  end

  @doc """
  Indicates whether an app is loaded. Useful to ask whether :distillery
  is loaded.
  """
  def is_app_loaded?(app) do
    app in Enum.map(Application.loaded_applications, &elem(&1,0) )
  end

  @doc """
  Returns dir path for the in-source-tree
  configuration directory.
  """
  def src_conf_dir(app) do
    umbrella_app = Path.join([File.cwd!, "apps", "#{app}"])
    if Mix.Project.umbrella? and is_app_loaded?(:distillery) and File.exists?(umbrella_app) do
      Path.join([umbrella_app, "config"])
    else
      Path.join([File.cwd!, "config"])
    end
  end
end
