defmodule Conform.Type.Enum do  
  def to_doc(values) do
    "Allowed values: #{Enum.join(values, ", ")}\n"
  end
  
  def transition(mapping, val) do
    check_enum(mapping, val)
  end
  
  def transition(mapping, val, _acc) do
    check_enum(mapping, val)
  end

  def parse_datatype(_key, val) when is_list(val) do
    List.to_atom(val)
  end

  def parse_datatype(_key, val) do
    val
  end
  
  defp check_enum(mapping, val) do
    valid_values = Keyword.get(mapping, :datatype) |> Keyword.get(Conform.Type.Enum)
    case Keyword.get(mapping, :default) do
      nil ->
        val
      _default ->
        if val in valid_values do
          val
        else
          {:error, "Wrong value of the enum"}
        end
    end
  end
end
