[
  extends: [],
  import: [],
  mappings: [
    "phoenix.generators.migration": [
      commented: true,
      datatype: :atom,
      default: true,
      doc: "Provide documentation for phoenix.generators.migration here.",
      hidden: false,
      to: "phoenix.generators.migration"
    ],
    "phoenix.generators.binary_id": [
      commented: true,
      datatype: :atom,
      default: false,
      doc: "Provide documentation for phoenix.generators.binary_id here.",
      hidden: false,
      to: "phoenix.generators.binary_id"
    ],
    "guardian.Elixir.Guardian.issuer": [
      commented: true,
      datatype: :binary,
      default: "MegaMaid",
      doc: "The name of the issuer of the security token. Really just this application's name.",
      hidden: false,
      to: "guardian.Elixir.Guardian.issuer"
    ],
    # This one is broken in Conform
    # "guardian.Elixir.Guardian.ttl": [
    #   commented: false,
    #   datatype: {:atom, :atom},
    #   default: {30, :days},
    #   doc: "Provide documentation for guardian.Elixir.Guardian.ttl here.",
    #   hidden: false,
    #   to: "guardian.Elixir.Guardian.ttl"
    # ],
    "guardian.Elixir.Guardian.verify_issuer": [
      commented: true,
      datatype: :atom,
      default: true,
      doc: "Should the issuer of the token be verified? The answer is yes.",
      hidden: false,
      to: "guardian.Elixir.Guardian.verify_issuer"
    ],
    "guardian.Elixir.Guardian.secret_key": [
      commented: true,
      datatype: :binary,
      default: "not secret, override in mega_maid.conf",
      doc: "The secret key used to encrypt the Guardian token. This should be kept secure to ensure fake tokens cannot be generated.",
      hidden: false,
      to: "guardian.Elixir.Guardian.secret_key"
    ],
    "guardian.Elixir.Guardian.serializer": [
      commented: false,
      datatype: :atom,
      default: MegaMaid.GuardianSerializer,
      doc: "The module that converts from the Guardian token to a User and back. DO NOT CHANGE THIS.",
      hidden: true,
      to: "guardian.Elixir.Guardian.serializer"
    ],
    "guardian.Elixir.Guardian.permissions": [
      commented: false,
      datatype: :binary,
      doc: "Provide documentation for guardian.Elixir.Guardian.permissions here.",
      hidden: false,
      to: "guardian.Elixir.Guardian.permissions"
    ],
    "logger.console.format": [
      commented: true,
      datatype: :binary,
      default: """
      $date $time $metadata[$level] $message
      """,
      doc: "The format of the logs.",
      hidden: false,
      to: "logger.console.format"
    ],
    "logger.console.metadata": [
      commented: true,
      datatype: [
        list: :atom
      ],
      default: [
        :request_id
      ],
      doc: "Metadata to add to the logs. DO NOT CHANGE THIS IF YOU DO NOT KNOW WHAT THAT MEANS.",
      hidden: false,
      to: "logger.console.metadata"
    ],
    "logger.level": [
      commented: true,
      datatype: [enum: [:info, :error, :warn, :debug]],
      default: :info,
      doc: "The Logging level.",
      hidden: false,
      to: "logger.level"
    ],
    "mega_maid.Elixir.MegaMaid.Endpoint.render_errors.accepts": [
      commented: false,
      datatype: [
        list: :binary
      ],
      default: [
        "html",
        "json"
      ],
      doc: "Provide documentation for mega_maid.Elixir.MegaMaid.Endpoint.render_errors.accepts here.",
      hidden: true,
      to: "mega_maid.Elixir.MegaMaid.Endpoint.render_errors.accepts"
    ],
    "mega_maid.Elixir.MegaMaid.Endpoint.pubsub.name": [
      commented: true,
      datatype: :atom,
      default: MegaMaid.PubSub,
      doc: "DO NOT CHANGE THIS",
      hidden: true,
      to: "mega_maid.Elixir.MegaMaid.Endpoint.pubsub.name"
    ],
    "mega_maid.Elixir.MegaMaid.Endpoint.pubsub.adapter": [
      commented: false,
      datatype: :atom,
      default: Phoenix.PubSub.PG2,
      doc: "Module for pubsup adapter. DO NOT CHANGE THIS.",
      hidden: true,
      to: "mega_maid.Elixir.MegaMaid.Endpoint.pubsub.adapter"
    ],
    "mega_maid.Elixir.MegaMaid.Endpoint.http.port": [
      commented: true,
      datatype: :integer,
      default: 4000,
      doc: "The port that the webserver listens on locally.",
      hidden: false,
      to: "mega_maid.Elixir.MegaMaid.Endpoint.http.port"
    ],
    "mega_maid.Elixir.MegaMaid.Endpoint.url.host": [
      commented: true,
      datatype: :binary,
      default: "dat.example.com",
      doc: "The external host name of the site. Needs to be correct so that email URLs are correct, for example.",
      hidden: false,
      to: "mega_maid.Elixir.MegaMaid.Endpoint.url.host"
    ],
    "mega_maid.Elixir.MegaMaid.Endpoint.url.scheme": [
      commented: true,
      datatype: :binary,
      default: "https",
      doc: "The external protocol of the site. Needs to be correct so that email URLs are correct, for example",
      hidden: false,
      to: "mega_maid.Elixir.MegaMaid.Endpoint.url.scheme"
    ],
    "mega_maid.Elixir.MegaMaid.Endpoint.url.port": [
      commented: true,
      datatype: :integer,
      default: 443,
      doc: "The external port of the site. Needs to be correct so that email URLs are correct, for example.",
      hidden: false,
      to: "mega_maid.Elixir.MegaMaid.Endpoint.url.port"
    ],
    "mega_maid.Elixir.MegaMaid.Endpoint.root": [
      commented: false,
      datatype: :binary,
      default: ".",
      doc: "Provide documentation for mega_maid.Elixir.MegaMaid.Endpoint.root here.",
      hidden: true,
      to: "mega_maid.Elixir.MegaMaid.Endpoint.root"
    ],
    # "mega_maid.Elixir.MegaMaid.Endpoint.force_ssl.rewrite_on": [
    #   commented: false,
    #   datatype: [
    #     list: :atom
    #   ],
    #   default: [
    #     :x_forwarded_proto
    #   ],
    #   doc: "Provide documentation for mega_maid.Elixir.MegaMaid.Endpoint.force_ssl.rewrite_on here.",
    #   hidden: false,
    #   to: "mega_maid.Elixir.MegaMaid.Endpoint.force_ssl.rewrite_on"
    # ],
    "mega_maid.Elixir.MegaMaid.Endpoint.check_origin": [
      commented: false,
      datatype: [
        list: :binary
      ],
      default: [
        "//dat.example.com}"
      ],
      doc: "The URLs that this site can be accessed with. This allows CORS checks to work correctly.",
      hidden: false,
      to: "mega_maid.Elixir.MegaMaid.Endpoint.check_origin"
    ],
    "mega_maid.Elixir.MegaMaid.Endpoint.cache_static_manifest": [
      commented: false,
      datatype: :binary,
      default: "priv/static/manifest.json",
      doc: "The manifest containing the mapping of file names to their fingerprinted files.",
      hidden: true,
      to: "mega_maid.Elixir.MegaMaid.Endpoint.cache_static_manifest"
    ],
    "mega_maid.Elixir.MegaMaid.Endpoint.secret_key_base": [
      commented: true,
      datatype: :binary,
      default: "changeme",
      doc: "Secret key used for encrypting cookies.",
      hidden: false,
      to: "mega_maid.Elixir.MegaMaid.Endpoint.secret_key_base"
    ],
    "mega_maid.Elixir.MegaMaid.Endpoint.server": [
      commented: false,
      datatype: :atom,
      default: true,
      doc: "DO NOT CHANGE THIS.",
      hidden: true,
      to: "mega_maid.Elixir.MegaMaid.Endpoint.server"
    ],
    "mega_maid.Elixir.MegaMaid.Repo.adapter": [
      commented: false,
      datatype: :atom,
      default: Ecto.Adapters.Postgres,
      doc: "The database adapter. DO NOT CHANGE THIS.",
      hidden: false,
      to: "mega_maid.Elixir.MegaMaid.Repo.adapter"
    ],
    "mega_maid.Elixir.MegaMaid.Repo.username": [
      commented: true,
      datatype: :binary,
      default: "dat_user",
      doc: "The database username used to conect to the DAT database.",
      hidden: false,
      to: "mega_maid.Elixir.MegaMaid.Repo.username"
    ],
    "mega_maid.Elixir.MegaMaid.Repo.password": [
      commented: false,
      datatype: :binary,
      default: "SECRET",
      doc: "The database password used to conect to the DAT database.",
      hidden: false,
      to: "mega_maid.Elixir.MegaMaid.Repo.password"
    ],
    "mega_maid.Elixir.MegaMaid.Repo.hostname": [
      commented: true,
      datatype: :binary,
      default: "DB_HOST",
      doc: "The database host where the DAT database is running",
      hidden: false,
      to: "mega_maid.Elixir.MegaMaid.Repo.hostname"
    ],
    "mega_maid.Elixir.MegaMaid.Repo.database": [
      commented: true,
      datatype: :binary,
      default: "dat_db",
      doc: "The database name of the DAT database.",
      hidden: false,
      to: "mega_maid.Elixir.MegaMaid.Repo.database"
    ],
    "mega_maid.Elixir.MegaMaid.Repo.pool_size": [
      commented: true,
      datatype: :integer,
      default: 20,
      doc: "The DB conection pool size",
      hidden: false,
      to: "mega_maid.Elixir.MegaMaid.Repo.pool_size"
    ],
    "mega_maid.example_live_puller": [
      commented: false,
      datatype: :atom,
      default: ExampleLive.Sync.Puller,
      doc: "Provide documentation for mega_maid.example_live_puller here.",
      hidden: true,
      to: "mega_maid.example_live_puller"
    ],
    "mega_maid.example_live_deleter": [
      commented: false,
      datatype: :atom,
      default: ExampleLive.Sync.Deleter,
      doc: "Provide documentation for mega_maid.example_live_deleter here.",
      hidden: true,
      to: "mega_maid.example_live_deleter"
    ],
    "mega_maid.mode": [
      commented: true,
      datatype: [enum: [:college, :pro, :normal]],
      default: :pro,
      doc: "Which mode to run in, college or pro",
      hidden: false,
      to: "mega_maid.mode"
    ],
    "mega_maid.mailgun_domain": [
      commented: false,
      datatype: :binary,
      default: "https://api.mailgun.net/v3/sandboxxxx.mailgun.org",
      doc: "The Mailgun domain.",
      hidden: false,
      to: "mega_maid.mailgun_domain"
    ],
    "mega_maid.mailgun_key": [
      commented: false,
      datatype: :binary,
      default: "key-xxxxx",
      doc: "The Mailgun API key",
      hidden: false,
      to: "mega_maid.mailgun_key"
    ],
    "mega_maid.example_live_endpoint": [
      commented: false,
      datatype: :binary,
      default: "http://pulsar.example.com/api",
      doc: "The URL of the Pulsar API to push data to.",
      hidden: false,
      to: "mega_maid.example_live_endpoint"
    ],
    "mega_maid.example_live_pusher": [
      commented: false,
      datatype: :atom,
      default: ExampleLive.Sync.Pusher,
      doc: "Provide documentation for mega_maid.example_live_pusher here.",
      hidden: true,
      to: "mega_maid.example_live_pusher"
    ]
  ],
  transforms: [],
  validators: []
]
