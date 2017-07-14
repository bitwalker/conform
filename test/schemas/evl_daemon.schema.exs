[
  extends: [],
  import: [
  ],
  mappings: [
    "evl_daemon.mailer_api_key": [
      commented: false,
      datatype: :binary,
      default: "SECRET",
      doc: "The API key from our mail provider.",
      hidden: false,
      to: "evl_daemon.Elixir.EvlDaemon.Mailer.api_key"
    ],
    "evl_daemon.host": [
      commented: false,
      datatype: :charlist,
      default: [
        49,
        50,
        55,
        46,
        48,
        46,
        48,
        46,
        49
      ],
      doc: "The host IP address for the EVL module.",
      hidden: false,
      to: "evl_daemon.host"
    ],
    "evl_daemon.port": [
      commented: false,
      datatype: :integer,
      default: 4025,
      doc: "The port number for the EVL module.",
      hidden: false,
      to: "evl_daemon.port"
    ],
    "evl_daemon.password": [
      commented: false,
      datatype: :binary,
      default: "SECRET",
      doc: "The password for the EVL module's web interface.",
      hidden: false,
      to: "evl_daemon.password"
    ],
    "evl_daemon.auto_connect": [
      commented: false,
      datatype: :atom,
      default: false,
      doc: "Determines if we should connect automatically when the application starts.",
      hidden: false,
      to: "evl_daemon.auto_connect"
    ],
    "evl_daemon.event_notifiers": [
      commented: false,
      datatype: [
        list: [list: {:atom, :binary}]
      ],
      default: [
        [type: :console],
        [type: :email, recipient: "person@example.com", sender: "noreply@example.com"]
      ],
      doc: "Enabled event notifiers and their options.",
      hidden: false,
      to: "evl_daemon.event_notifiers"
    ],
    "evl_daemon.storage_engines": [
      commented: false,
      datatype: [
        list: [list: {:atom, :binary}]
      ],
      default: [
        [type: :memory, maximum_events: "100"]
      ],
      doc: "Enabled storage engines and their options.",
      hidden: false,
      to: "evl_daemon.storage_engines"
    ],
    "evl_daemon.zones": [
      commented: true,
      doc: "Zone mapping in the form of [number, \"description\"].",
      hidden: false,
      to: "evl_daemon.zones",
      datatype: [list: [list: :charlist]]
    ],
    "evl_daemon.partitions": [
      commented: true,
      doc: "Partition mapping in the form of [number, \"description\"].",
      hidden: false,
      to: "evl_daemon.partitions",
      datatype: [list: [list: :charlist]]
    ],
    "evl_daemon.system_emails_sender": [
      commented: false,
      datatype: :binary,
      default: "noreply@example.com",
      doc: "The sender address for system emails.",
      hidden: false,
      to: "evl_daemon.system_emails_sender"
    ],
    "evl_daemon.system_emails_recipient": [
      commented: false,
      datatype: :binary,
      default: "user@example.com",
      doc: "The recipient address for system emails.",
      hidden: false,
      to: "evl_daemon.system_emails_recipient"
    ],
    "evl_daemon.log_level": [
      commented: false,
      datatype: [enum: [:debug, :info, :warn, :error]],
      default: :info,
      doc: "The logging level for the default logger.",
      hidden: false,
      to: "logger.level"
    ],
    "evl_daemon.auth_token": [
      commented: false,
      datatype: :binary,
      default: "SECRET",
      doc: "The authentication token to access EVL Daemon over HTTP.",
      hidden: false,
      to: "evl_daemon.auth_token"
    ],
  ],
  transforms: [
    "evl_daemon.zones": fn (conf) ->
      [{key, zones}]  = Conform.Conf.get(conf, "evl_daemon.zones")

      Enum.reduce(zones, Map.new, fn [zone, description], zone_map ->
         Map.put(
           zone_map,
           zone |> to_string |> String.pad_leading(3, "0"),
           List.to_string(description)
         )
      end)
    end,
    "evl_daemon.partitions": fn (conf) ->
      [{key, partitions}]  = Conform.Conf.get(conf, "evl_daemon.partitions")

      Enum.reduce(partitions, Map.new, fn [partition, description], partition_map ->
         Map.put(
           partition_map,
           partition |> to_string,
           List.to_string(description)
         )
      end)
    end
  ],
  validators: []
]
