defmodule Conform.Types.Enum do
  @moduledoc """
  Custom type for enumerations, i.e. [:a, :b, :c]

  ## Usage

      [ mapping: [
        "foo.bar": [
          datatype: [Conform.Types.Enum: [:a, :b, :c]],
          default: :a,
          ...
        ]]]
  """
  use Conform.Type
  alias Conform.Schema.Mapping

  def to_doc(values), do: "Allowed values: #{Enum.join(values, ", ")}\n"

  def convert(nil, %Mapping{default: nil, datatype: [{_, values}]}) do
    {:error, invalid_msg(nil, values)}
  end
  def convert(nil, %Mapping{default: default}), do: {:ok, default}
  def convert(value, %Mapping{default: default, datatype: [{_, valid_values}]}) do
    parsed = case value do
      nil -> default
      val when is_list(val) -> List.to_atom(val)
      val when is_binary(val) -> String.to_atom(val)
    end
    case parsed in valid_values do
      true  -> {:ok, parsed}
      false -> {:error, invalid_msg(parsed, valid_values)}
    end
  end

  defp invalid_msg(value, valid_values) do
    "#{value} is not a valid value of the enum [#{Enum.join(valid_values, ", ")}]"
  end
end
