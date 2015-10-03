[
  mappings: [
    "dep.some_val": [
      to: "dep.some_val",
      datatype: :binary,
      default: "/var/log/error.log",
      doc: "Just a value"
    ],
    "lager.handlers.console.level": [
      to: "lager.handlers.lager_console_backend",
      datatype: [enum: [:info, :error]],
      default: :info,
      doc: """
      Choose the logging level for the console backend.
      """
    ],
    "lager.handlers.$backend": [
      to: "lager.handlers.lager_$backend_backend",
      datatype: :complex,
      default: []
    ],
    "lager.handlers.file.error": [
      to: "lager.handlers.file.error",
      datatype: :binary,
      default: "/var/log/error.log",
      doc: """
      Specify the path to the error log for the file backend
      """
    ],
    "lager.handlers.file.info": [
      to: "lager.handlers.file.info",
      datatype: :binary,
      default: "/var/log/console.log",
      doc: """
      Specify the path to the console log for the file backend
      """
    ],
    "myapp.some.important.setting": [
      to: "myapp.some.important.setting",
      datatype: [list: :ip],
      default: [{"127.0.0.1", "8001"}],
      doc: "Seriously, super important."
    ]
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
