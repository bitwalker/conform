[
  mappings: [
    "fld1.fld2.fld3": [
      to: "fld1.fld2.fld3",
      datatype: :integer,
      default: :undefined
    ],
    "fld1.fld2.fld4": [
      to: "fld1.fld2.fld4",
      datatype: :integer,
      default: :undefined
    ]
  ],
  transforms: [
    "fld1": fn conf ->
      Enum.reduce(Conform.Conf.get(conf, "fld1.$node1.$node2"), %{},
      fn({['fld1', node1, node2], val}, acc) ->
        key = String.to_atom(to_string(node2))
        case acc[node1] do
          nil ->
            Map.put(acc, node1, %{ key => val })
          map ->
            Map.put(acc, node1, Map.put(map, key, val))
        end
      end)
      |> Map.values
    end
  ]
]
