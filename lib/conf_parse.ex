defmodule Conform.Parse do
  def file(f),       do: :conf_parse.file(f)
  def parse(binary), do: :conf_parse.parse(binary)
end