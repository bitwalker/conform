defmodule Conform.Schema.Mapping do
  @moduledoc """
  This module defines a struct which represents a mapping definition.

  ## Definitions

  - "path" - A string of dot-separated tokens which represent the path to a setting,
  a path can contain variables which represent wildcard values such that any value at
  that point in the path is valid.

  ## Fields
  - `name` is the name of the setting in the .conf, it should be a path as defined above
  - `to` is the name of the setting in the sys.config, it should be a path as defined above
  - `datatype` is the type of the value this setting will be mapped to, see the documentation
  for information on what datatypes are available. User-defined types are also possible.
  - `default` the default value to use if one is not provided in the .conf
  - `env_var` if set, will use the value of the given environment variable as the default value for this option
  - `doc` the documentation comment which will accompany this setting in the generated .conf
  - `see` the name of another setting which you wrote a `doc` for, but which also describes this
  setting. Used when describing how multiple settings work together, as it's just a pointer to
  additional documentation. It will be output as a comment in the generated .conf
  - `commented` is a boolean which determines whether this setting should be commented by default
  in the generated .conf
  - `hidden` is a boolean which determines whether this setting will be placed in the generated .conf,
  in this way you can provided "advanced" settings which can be configured but only by those who know
  they exist.
  - `include_default` if set to a string, it will be used in place of a wildcard value when generating a .conf,
  if nil, the generated .conf will contain a commented default which contains the wildcard in the path.
  - `validators` a list of validator names which will be executed against the value of this setting once it has
  been mapped to the defined datatype.
  """
  alias Conform.Schema.Mapping
  defstruct name: "",
            to: nil,
            datatype: :binary,
            default: nil,
            env_var: nil,
            doc: "",
            see: "",
            commented: false,
            hidden: false,
            include_default: nil,
            validators: [],
            persist: true

  def from_quoted({name, mapping}) when is_list(mapping) do
    case Keyword.keyword?(mapping) do
      false -> raise Conform.Schema.SchemaError, message: "Invalid mapping for #{name}: `#{inspect(mapping)}`."
      true  ->
        do_from(mapping, %Mapping{name: Atom.to_string(name)})
    end
  end

  defp do_from([{:to, to}|rest], mapping) when is_binary(to),       do: do_from(rest, %{mapping | :to => to})
  defp do_from([{:datatype, dt}|rest], mapping),                    do: do_from(rest, %{mapping | :datatype => dt})
  defp do_from([{:default, default}|rest], mapping),                do: do_from(rest, %{mapping | :default => default})
  defp do_from([{:env_var, env_var}|rest], mapping),                do: do_from(rest, %{mapping | :env_var => env_var})
  defp do_from([{:doc, doc}|rest], mapping) when is_binary(doc),    do: do_from(rest, %{mapping | :doc => doc})
  defp do_from([{:see, see}|rest], mapping) when is_binary(see),    do: do_from(rest, %{mapping | :see => see})
  defp do_from([{:hidden, h}|rest], mapping) when is_boolean(h),    do: do_from(rest, %{mapping | :hidden => h})
  defp do_from([{:commented, c}|rest], mapping) when is_boolean(c), do: do_from(rest, %{mapping | :commented => c})
  defp do_from([{:include_default, default}|rest], mapping) when is_binary(default),
    do: do_from(rest, %{mapping | :include_default => default})
  defp do_from([{:validators, vs}|rest], mapping) when is_list(vs), do: do_from(rest, %{mapping | :validators => vs})
  defp do_from([_|rest], mapping), do: do_from(rest, mapping)
  defp do_from([], mapping),       do: mapping
end
