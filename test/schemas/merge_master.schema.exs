[
  mappings: [
    "lager.handlers.console.level": [
      to: "lager.handlers.lager_console_backend.level",
      datatype: [enum: [:info, :error]],
      default: :info,
      doc: """
      Choose the logging level for the console backend.
      """
    ],
    "lager.handlers.file.error": [
      to: "lager.handlers.lager_file_backend.error",
      datatype: :binary,
      default: "/var/log/error.log",
      doc: """
      Specify the path to the error log for the file backend
      """
    ],
    "lager.handlers.file.info": [
      to: "lager.handlers.lager_file_backend.info",
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
    "lager.handlers": fn conf ->
      file_handlers = case Conform.Conf.find(conf, "lager.handlers.lager_file_backend.$key") do
        [] -> []
        levels when is_list(levels) ->
          Enum.map(levels, fn {[_, _, _, level], path} ->
            {:lager_file_backend, [level: List.to_atom(level), file: path]}
          end)
      end
      console_handler = case Conform.Conf.get(conf, "lager.handlers.lager_console_backend.level") do
        []              -> []
        [{_path, level}] -> [lager_console_backend: level]
      end
      Conform.Conf.remove(conf, "lager.handlers")
      console_handler ++ file_handlers
    end
  ]
]
