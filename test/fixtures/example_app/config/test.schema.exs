[
  import:  [:fake_app],
  extends: [:fake_app],
  mappings: [
    "test.env": [
      doc: "Provide documentation for test.env here.",
      to: "test.env",
      datatype: [{:'Conform.Types.Enum', [:dev, :prod]}],
      default: :dev
    ],
    "test.some_val": [
      doc: "Just a sample transformed value",
      to: "test.another_val",
      datatype: :integer,
      default: 1
    ],
    "test.debug_level": [
      doc: "Provide documentation for test.debug_level here.",
      to:  "test.debug_level",
      datatype: [enum: [:info, :warn, :error]],
      default: :info
    ]
  ],
  transforms: [
    "test.another_val": fn conf ->
      case Conform.Conf.get(conf, "test.another_val") do
        [{_, val}] -> FakeApp.inc_val_test(val)
        []  -> nil
      end
    end
  ]
]
