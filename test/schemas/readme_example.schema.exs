[
  extends: [],
  import: [],
  mappings: [
    "lager.handlers.console.level": [
      doc: """
      Choose the logging level for the console backend.
      """,
      to: "lager.handlers.lager_console_backend",
      datatype: [enum: [:info, :error]],
      default: :info
    ],
    "lager.handlers.file.error": [
      doc: """
      Specify the path to the error log for the file backend
      """,
      to: "lager.handlers.lager_file_backend.error",
      datatype: :binary,
      default: "/var/log/error.log"
    ],
    "lager.handlers.file.info": [
      doc: """
      Specify the path to the console log for the file backend
      """,
      to: "lager.handlers.lager_file_backend.info",
      datatype: :binary,
      default: "/var/log/console.log",
      env_var: "LAGER_INFO_FILE"
    ],
    "my_app.nodelist": [
      doc: "A simple list",
      to: "my_app.nodelist",
      datatype: [list: :atom],
      default: [:'a@foo', :'b@foo']
    ],
    "my_app.db.hosts": [
      doc: "Remote database hosts",
      to: "my_app.db.hosts",
      datatype: [list: :ip],
      default: [{"127.0.0.1", "8001"}]
    ],
    "my_app.some_val": [
      doc:      "Just some atom.",
      to:       "my_app.some_val",
      datatype: :atom,
      default:  :foo
    ],
    "my_app.another_val": [
      doc: "Just another enum",
      to: "my_app.another_val",
      datatype: :atom,
      default: :none
    ],
    "my_app.complex_list.*": [
      to: "my_app.complex_list",
      datatype: [list: :complex],
      default: []
    ],
    "my_app.complex_list.*.username": [
      to: "my_app.complex_list",
      datatype: :binary,
      required: true
    ],
    "my_app.complex_list.*.age": [
      to: "my_app.complex_list",
      datatype: :integer,
      default: 30
    ],
    "my_app.max_demand": [
      to: "my_app.max_demand",
      datatype: :integer,
      default: nil
    ],
    "evl_daemon.storage_engines": [
      commented: false,
      datatype: [
        list: [list: {:atom, :binary}]
      ],
      default: [
        [type: "memory", maximum_events: "100"]
      ],
      doc: "Enabled storage engines and their options.",
      hidden: false,
      to: "evl_daemon.storage_engines"
    ],
  ],

  transforms: [
    "my_app.another_val": fn conf ->
      case Conform.Conf.get(conf, "my_app.another_val") do
        [{_, :all}]  -> {:on, [debug: true, tracing: true]}
        [{_, :some}] -> {:on, [debug: true]}
        [{_, :none}] -> {:off, []}
        _            -> {:off, []}
      end
    end,
    "my_app.max_demand": fn conf ->
      res = Conform.Conf.get(conf, "my_app.max_demand")
      case res do
        [{_, n}] when is_integer(n) and n > 0 -> n
        _ -> 40
      end
    end,
    "lager.handlers": fn conf ->
      backends = Conform.Conf.find(conf, "lager.handlers.$backend")
      |> Enum.reduce([], fn
        {[_,_,'lager_file_backend', level], path}, acc ->
          [{:lager_file_backend, [level: :"#{level}", file: path]}|acc]
        {[_,_,'lager_console_backend'], level}, acc ->
          [{:lager_console_backend, level}|acc]
      end)
      Conform.Conf.remove(conf, "lager.handlers.$backend")
      backends
    end,
  ]
]
