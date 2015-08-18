[
  mappings: [
    "test.some_val": [
      doc: "Just a sample transformed value",
      to: "test.another_val",
      datatype: :atom,
      default: "none"
    ],
    "test.debug_level": [
      doc: "Provide documentation for test.debug_level here.",
      to: "test.debug_level",
      datatype: [enum: [:info, :warn, :error]],
      default: :info
    ]
  ]
]
