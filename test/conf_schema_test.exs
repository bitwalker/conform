defmodule ConfSchemaTest do
  use ExUnit.Case, async: true
  alias Conform.Schema
  alias Conform.Schema.Mapping

  test "can load schema from file" do
    path   = Path.join(["test", "schemas", "small.schema.exs"])
    %Schema{mappings: [mapping], transforms: transforms} = Conform.Schema.load!(path)

    assert %Mapping{name:     "log.error.file",
                    to:       "log.error_file",
                    datatype: :binary,
                    default:  "/var/log/error.log",
                    doc:      "The location of the error log. Should be a full path, i.e. /var/log/error.log."} = mapping
    assert [] = transforms
  end
end
