defmodule ConfSchemaTest do
  use ExUnit.Case, async: true

  test "can load schema from file" do
    path   = Path.join(["test", "schemas", "small.schema.exs"])
    schema = path |> Conform.Schema.load!

    assert schema == [mappings: [
                        "log.error.file": [
                          to:       "log.error_file",
                          datatype: :binary,
                          default:  "/var/log/error.log",
                          doc:      "The location of the error log. Should be a full path, i.e. /var/log/error.log."
                        ],
                      ],
                      translations: [] ]
  end
end
