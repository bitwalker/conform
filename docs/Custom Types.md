# Custom Types

`Conform` provides ability to use custom data types in your schemas:

```elixir
[
    mappings: [
      "myapp.val1": [
        doc: "Provide some documentation for val1",
        to: "myapp.val1",
        datatype: MyModule1,
        default: 100
      ],
      "myapp.val2": [
        doc: "Provide some documentation for val2",
        to: "myapp.val2",
        datatype: [{MyModule2, [:dev, :prod, :test]}],
        default: :dev
      ]
    ],

    transforms: [
       ...
       ...
       ...
    ]
]
```

Where `MyModule1` and `MyModule2` must be modules which implement the `Conform.Type` behaviour:

```elixir
defmodule MyModule1 do
  use Conform.Type

  # Return a string to produce documentation for the given type based on it's valid values (if specified).
  # If nil is returned, the documentation specified in the schema will be used instead (if present).
  def to_doc(values) do
    "Document your custom type here"
  end

  # Converts the .conf value to this data type.
  # Should return {:ok, term} | {:error, term}
  def convert(val, _mapping) do
    {:ok, val}
  end
end
```
