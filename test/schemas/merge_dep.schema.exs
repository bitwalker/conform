[
  mappings: [
    "dep.some_val": [
      to:       "dep.some_val",
      datatype: :binary,
      default:  "/var/log/error.log",
      doc:      "Just a value"
    ],
  ],
  transforms: [
    "dep.some_val": fn conf ->
      exists? = case Conform.Conf.get(conf, "dep.some_val") do
        [{_, path}] when is_binary(path) -> File.exists?(path)
        _ -> false
      end
      if exists?, do: "success", else: "n/a"
    end
  ]
]
