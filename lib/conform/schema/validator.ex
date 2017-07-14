defmodule Conform.Schema.Validator do
  @moduledoc """
  This module defines the behaviour for custom validators.

  Validators can be defined inline in which case this behaviour need not be used,
  but if you want to define reusable validators which you can reference in your
  schema, you should implement this behaviour, and then import the application in
  your schema so that they are made available by the module name.

  ## Example

  app.schema.exs:
      [ mappings: [
        "foo.bar": [
          datatype: :integer,
          default: 1,
          validators: [MyApp.RangeValidator: 1..2, MyApp.PositiveIntegerValidator]
        ]
      ]]

  app.conf:
      foo.bar = 3

  In the example above, `foo.bar` will be first parsed and mapped as the integer value 3,
  and then validated by calling `MyApp.RangeValidator.validate(3, [1..2])` where the second
  parameter is an optional list of extra arguments used by the validator. The second validator
  will then be called like `MyApp.PositiveIntegerValidator.validate(3, [])`.

  Validators must return `:ok` if validation passed, `{:warn, message}` if validation passed but a warning
  should be printed to stdout (for instance if you set a value to a valid but extreme value), or
  `{:error, message}` if validation failed.
  """
  alias Conform.Schema.Validator

  defmacro __using__(_) do
    quote do
      @behaviour Conform.Schema.Validator
    end
  end

  defstruct name: nil,       # The name of this validator
            validator: nil,  # The validator function
            definition: "",  # The definition of the validator function as a string
            persist: true

  @callback validate(term, [term]) :: :ok | {:warn, String.t} | {:error, String.t}

  def from_quoted(name) when is_atom(name) do
    %Validator{definition: nil, validator: name}
  end
  def from_quoted({_, _, module_path}) do
    %Validator{definition: nil, validator: Module.concat(module_path)}
  end
  def from_quoted({name, validator}) when is_function(validator, 1) do
    definition = validator
    case is_function(validator, 1) do
      true ->
        %Validator{name: Atom.to_string(name), definition: definition, validator: validator}
      false ->
        raise Conform.Schema.SchemaError, message: "Invalid validator #{name}, it must be a function of arity 1."
    end
  end

  @doc """
  Loads all user-defined Validator modules.
  """
  @spec load() :: [%Validator{}]
  def load() do
    Conform.Utils.load_plugins_of(__MODULE__)
    |> Enum.map(fn module -> %Validator{definition: nil, validator: module} end)
  end
end
