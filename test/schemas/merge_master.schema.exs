[
  mappings: [
    "lager.handlers.console.level": [
      to: "lager.handlers",
      datatype: [enum: [:info, :error]],
      default: :info,
      doc: """
      Choose the logging level for the console backend.
      """
    ],
    "lager.handlers.file.error": [
      to: "lager.handlers",
      datatype: :binary,
      default: "/var/log/error.log",
      doc: """
      Specify the path to the error log for the file backend
      """
    ],
    "lager.handlers.file.info": [
      to: "lager.handlers",
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
  translations: [
    "lager.handlers.console.level": fn
      _mapping, level, nil when level in [:info, :error] ->
          [lager_console_backend: level]
      _mapping, level, acc when level in [:info, :error] ->
          acc ++ [lager_console_backend: level]
      _mapping, level, _ ->
        IO.puts("Unsupported console logging level: #{level}")
        exit(1)
    end,
    "lager.handlers.file.error": fn 
      _mapping, path, nil ->
        [lager_file_backend: [file: path, level: :error]]
      _mapping, path, acc ->
        acc ++ [lager_file_backend: [file: path, level: :error]]
    end,
    "lager.handlers.file.info": fn
      _mapping, path, nil ->
        [lager_file_backend: [file: path, level: :info]]
      _mapping, path, acc ->
        acc ++ [lager_file_backend: [file: path, level: :info]]
    end,
    "myapp.some.important.setting": fn _mapping, val, _ ->
      val
    end
  ]
]