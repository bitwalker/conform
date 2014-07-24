[
  mappings: [
    "dep.some_val": [
      to:       "dep.some_val",
      datatype: :binary,
      default:  "/var/log/error.log",
      doc:      "Just a value"
    ],
  ],
  translations: [
    "dep.some_val": fn _mapping, val ->
      if File.exists?(val) do
        "success"
      else
        "n/a"
      end
    end
  ]
]