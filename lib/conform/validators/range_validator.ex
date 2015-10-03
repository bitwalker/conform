defmodule Conform.Validators.RangeValidator do
  use Conform.Schema.Validator

  def validate(value, [x..y]) when is_integer(value) do
    cond do
      value > y -> {:error, "#{value} cannot be greater than #{x}..#{y}"}
      value < x -> {:error, "#{value} cannot be less than #{x}..#{y}"}
      true      -> :ok
    end
  end
  def validate(value, [x..y]) when is_float(value) do
    cond do
      value > y -> {:error, "#{value} cannot be greater than #{x}..#{y}"}
      value < x -> {:error, "#{value} cannot be less than #{x}..#{y}"}
      true      -> {:warn, "#{value} is valid for the range #{x}..#{y}, but is a float"}
    end
  end
  def validate(value, _) do
    {:error, "#{value} is not a number!"}
  end
end
