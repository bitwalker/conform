[
  mappings: [
    #
    # first complex
    #
    "complex_another_list.$person.username": [
      to: "my_app.complex_another_list.$person.username",
      datatype: :binary,
      default: :undefined
    ],
    "complex_another_list.$person.age": [
      to: "my_app.complex_another_list.$person.age",
      datatype: :integer,
      default: :undefined
    ],
    #
    # second complex
    #
    "complex_list.$person.type": [
      to: "my_app.complex_list.$person.type",
      datatype: :atom,
      default:  :undefined
    ],
    "complex_list.$person.age": [
      to: "my_app.complex_list.$person.age",
      datatype: :integer,
      default: 30,
      validators: ['Conform.Validators.RangeValidator': 1..100]
    ],
    # dynamic keyword list
    "sublist_example.$key": [
      to: "my_app.sublist.$key",
      datatype: :binary,
      default: []
    ],
    # just a val
    some_val: [
      doc:      "Just some atom.",
      to:       "my_app.some_val",
      datatype: :atom,
      default:  :foo
    ],

    some_val2: [
      doc:      "Just some float.",
      to:       "my_app.some_val2",
      datatype: :float,
      default:  2.5
    ]
  ],

  transforms: [
  ]
]
