[
  extends: [],
  import: [],
  mappings: [
    "log.error.file": [
      to:       "log.error_file",
      datatype: :binary,
      default:  "/var/log/error.log",
      doc:      "The location of the error log. Should be a full path, i.e. /var/log/error.log."
    ],
    "log.console.file": [
      to:       "log.console_file",
      datatype: :binary,
      default:  "/var/log/console.log",
      doc:      "The location of the console log. Should be a full path, i.e. /var/log/console.log."
    ],
    "log.syslog": [
      to:       "log.syslog",
      datatype: [enum: [:on, :off]],
      default:  :on,
      doc:      "This setting determines whether to use syslog or not. Valid values are :on and :off.",
    ],
    "sasl.log.level": [
      to:       "sasl.errlog_type",
      datatype: [enum: [:error, :progress, :all]],
      default:  :all,
      doc: """
      Restricts the error logging performed by the specified
      `sasl_error_logger` to error reports, progress reports, or
      both. Default is all. Just testing "nested strings".
      """
    ],
    "logger.format": [
      to: "logger.format",
      datatype: :binary,
      default: "$time $metadata[$level] $levelpad$message\n",
      doc: """
      The format to use for Logger.
      """
    ],
    "myapp.db.hosts": [
      to: "myapp.db.hosts",
      datatype: [list: :ip],
      default: [{"127.0.0.1", "8001"}],
      doc: "Remote db hosts"
    ],
    "myapp.some_val": [
      datatype: :atom,
      default:  :foo,
      doc:      "Just some atom."
    ],
    "some.string value": [
      datatype: :charlist,
      default: nil,
      doc: "Example of quoted keys",
      hidden: true,
    ],
    "starting string.key": [
      datatype: :charlist,
      default: 'empty',
      doc: "Example of quoted keys"
    ],
    "myapp.another_val": [
      to:       "myapp.another_val",
      datatype: [enum: [:active, :passive, :'active-debug']],
      default:  :active,
      doc: """
      Determine the type of thing.
      * active: it's going to be active
      * passive: it's going to be passive
      * active-debug: it's going to be active, with verbose debugging information
      """
    ],
    "myapp.Some.Module.val": [
      datatype: :atom,
      default:  :foo,
      doc:      "Atom module name"
    ],
    "myapp.Custom.Enum": [
      doc: "Provide documentation for myapp.Custom.Enum here.",
      to: "myapp.Custom.Enum",
      datatype: [{Conform.Types.Enum, [:dev, :prod, :test]}],
      default: :dev
     ],
     "myapp.volume": [
       doc: "The volume of some thing. Valid values are 1-11.",
       to: "myapp.volume",
       datatype: :integer,
       default: 1,
       validators: [{Conform.Validators.RangeValidator, 1..11}]
     ]
  ],

  transforms: [
    "myapp.another_val": fn conf ->
      case Conform.Conf.get(conf, "myapp.another_val") do
        [{_, val}] ->
          case val do
            :active ->
              data = %{log: :warn}
              more_data = %{data | :log => :warn}
              {:on, [data: data]}
            :'active-debug' -> {:on, [debug: true]}
            :passive        -> {:off, []}
            _               -> {:on, []}
          end
      end
    end,
    "myapp.some_val": fn conf ->
      case Conform.Conf.get(conf, "myapp.some_val") do
        [{_, :foo}] -> :bar
        [{_, val}]  -> val
      end
    end
  ]
]
