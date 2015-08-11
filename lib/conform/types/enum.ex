defmodule Conform.Types.Enum do
  @moduledoc """
  Custom type for enumerations, i.e. [:a, :b, :c]
  """
  use Conform.Type

  def to_doc(values), do: "Allowed values: #{Enum.join(values, ", ")}\n"

  def translate(mapping, val, _acc), do: check_enum(mapping, val)

  def parse_datatype(_key, val) when is_list(val), do: {:ok, List.to_atom(val)}
  def parse_datatype(_key, val),                   do: {:ok, val}

  defp check_enum(mapping, val) do
    valid_values = get_in(mapping, [:datatype, Conform.Types.Enum])
    case Keyword.get(mapping, :default) do
      nil      -> val
      _default ->
        if val in valid_values do
          val
        else
          {:error, "Invalid enum value for #{mapping}."}
        end
    end
  end
end
