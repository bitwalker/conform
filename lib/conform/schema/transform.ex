defmodule Conform.Schema.Transform do
  @moduledoc """
  This module defines the behaviour for custom transformations.

  Transformations can be defined inline, in which case this behaviour need not be used,
  but if you want to define reusable transforms which you can reference in your
  schema, you should implement this behaviour, and then import the application in
  your schema so that they are made available by the module name.

  ## Example

      [ mappings: [...],
        transforms: [
          "lager.handlers.lager_file_backend": MyApp.Transforms.ToLagerFileBackend,
          "lager.handlers.lager_console_backend": MyApp.Transforms.ToLagerConsoleBackend,
          "lager.handlers": fn conf ->
              file_handlers = Conform.Conf.get(conf, "lager.handlers.lager_file_backend.$level")
                |> Enum.map(fn {[_, _, backend, level], path} -> {backend, [level: level, path: path]} end)
              console_handlers = Conform.Conf.get(conf, "lager.handlers.lager_console_backend")
                |> Enum.map(fn {[_, _, backend], conf} -> {backend, conf}
              console_handlers ++ file_handlers
          end
        ]]

  In the case of the two transforms which reference a transform module, the `transform/1` function on each will
  be called with the current configuration state, which is a keyword list. Use the `Conform.Conf` module to query
  values from the configuration as shown in the example above.
  """
  alias Conform.Schema.Transform
  defmacro __using__(_) do
    quote do
      @behaviour Conform.Schema.Transform
    end
  end

  defstruct path: "",       # The path of the setting in sys.config where the transformed value will be placed
            transform: nil, # The transformation function
            definition: "", # The quoted function definition
            persist: true

  @callback transform([{term, term}]) :: [{term, term}]

  def from_quoted({key, transform}) when is_atom(transform) do
    %Transform{path: Atom.to_string(key), definition: nil, transform: transform}
  end
  def from_quoted({key, transform}) do
    definition = transform
    {transform, _} = Code.eval_quoted(transform)
    case is_function(transform, 1) do
      true ->
        %Transform{path: Atom.to_string(key), definition: definition, transform: transform}
      false ->
        raise Conform.Schema.SchemaError, message: "Invalid transform for #{key}, it must be a function of arity 1."
    end
  end
end
