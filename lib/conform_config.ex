defmodule Conform.Config do
  def write(path, config) do
    :file.write_file('#{path}', :io_lib.fwrite('~p.\n', [config]))
  end
end