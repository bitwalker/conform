[
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

    "myapp.some_val": [
      datatype: :atom,
      default:  :foo,
      doc:      "Just some atom."
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
    ]
  ],

  translations: [
    "myapp.another_val": fn
      _, :foo -> :bar
      _mapping, val ->
        case val do
          :active ->
            data = %{log: :warn}
            more_data = %{data | :log => :warn}
            {:on, [data: data]}
          :'active-debug' -> {:on, [debug: true]}
          :passive        -> {:off, []}
          _               -> {:on, []}
        end
    end,
    "myapp.some_val": fn
      _, :foo -> :bar
      _mapping, val ->
        case val do
          :foo -> :bar
          _    -> val
        end
    end
  ]
]