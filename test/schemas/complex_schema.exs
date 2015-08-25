[
  mappings: [
    #
    # first complex
    #
    "complex_another_list.*": [
      to: "my_app.complex_another_list",
      datatype: [:complex],
      default: []
    ],
    "complex_another_list.*.id": [
      to: "my_app.complex_another_list",
      datatype: :integer,
      default: :undefined
    ],
    "complex_another_list.*.dbid": [
      to: "my_app.complex_another_list",
      datatype: :integer,
      default: :undefined
    ],
    "complex_another_list.*.username": [
      to: "my_app.complex_another_list",
      datatype: :binary,
      default: :undefined
    ],
    "complex_another_list.*.age": [
      to: "my_app.complex_another_list",
      datatype: :integer,
      default: :undefined
    ],
    #
    # second complex
    #
    "complex_list.*": [
      to: "my_app.complex_list",
      datatype: [:complex],
      default: []
    ],
    "complex_list.*.type": [
      to: "my_app.complex_list",
      datatype: :atom,
      default:  :undefined
    ],
    "complex_list.*.age": [
      to: "my_app.complex_list",
      datatype: :integer,
      default: 30
    ],
    # dynamic keyword list
    "sublist_example.*": [
      to: "my_app.sublist",
      datatype: :binary,
      default: []
    ],
    # just a val
    "some_val": [
      doc:      "Just some atom.",
      to:       "my_app.some_val",
      datatype: :atom,
      default:  :foo
    ],

    "some_val2": [
      doc:      "Just some float.",
      to:       "my_app.some_val2",
      datatype: :float,
      default:  2.5
    ]
  ],

  translations: [
    "my_app.complex_list.*": fn _, {key, value_map}, acc ->
      [{key, %{
        type: value_map[:type],
        age:  value_map[:age]
       }} | acc]
    end,

    "my_app.complex_another_list.*": fn _, {key, value_map}, acc ->
      [{key, %{
        id: value_map[:id],
        username: value_map[:username],
        age: value_map[:age],
        dbid: value_map[:dbid]
       }} | acc]
    end,

    "my_app.sublist.*": fn _, {key, value_map}, acc ->
      [{key, value_map[key]}|acc]
    end
  ]
]
