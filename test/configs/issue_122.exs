use Mix.Config

config :tiser,
  ecto_repos: [Tiser.Repo]

config :tiser, Tiser.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "oIXBLJF+Ar+bjNUyPOxij3oCmH5F89Y2Y+fIozRckOLabpzoYYou1GsdFAOmNcHD",
  render_errors: [view: Tiser.Web.ErrorView, accepts: ~w(json)],
  pubsub: [name: Tiser.PubSub,
           adapter: Phoenix.PubSub.PG2]

config :logger, :console,
  format: "$date $time $metadata[$level] $message\n",
  handle_sasl_reports: true,
  handle_otp_reports: true,
  utc_log: true,
  metadata: [:module, :request_id]

config :logger,
  # compile_time_purge_level: :debug,
  format: "$date $date $time $metadata[$level] $message\n",
  backends: [
    {LoggerFileBackend, :info_log},
    {LoggerFileBackend, :error_log},
    {LoggerFileBackend, :debug_log},
    :console
  ],
  metadata: [:module],
  utc_log: true

config :logger, :info_log,
  format: "$date $time $node $metadata[$level] $message\n",
  path: "logs/info.log",
  handle_sasl_reports: true,
  handle_otp_reports: true,
  level: :info,
  utc_log: true,
  metadata: [:module],
  metadata_filter: [application: :tiser]

config :logger, :error_log,
  format: "$date $time $node $metadata[$level] $message\n",
  path: "logs/error.log",
  handle_sasl_reports: true,
  handle_otp_reports: true,
  level: :error,
  utc_log: true,
  metadata: [:module]

config :logger, :debug_log,
  format: "$date $time $node $metadata[$level] $message\n",
  path: "logs/debug.log",
  handle_sasl_reports: true,
  handle_otp_reports: true,
  level: :debug,
  utc_log: true,
  metadata: [:module]

config :guardian, Guardian,
  hooks: GuardianDb,
  allowed_algos: ["RS512"], # ["ES256", "ES384", "ES512", "HS256", "HS384", "HS512", "RS256", "RS384", "RS512"]
  verify_module: Guardian.JWT,
  issuer: "Toooooooooooooooooo",
  ttl: { 1, :days },
  verify_issuer: true,
  secret_key: "priv/keys/rsa-2048.pem",
  serializer: Tiser.GuardianSerializer

config :guardian_db, GuardianDb,
  repo: Tiser.Repo,
  schema_name: "auth_tokens",
  sweep_interval: 10 # 1 minute

config :tiser, Tiser.Web.Endpoint,
  http: [
    port: 4000,
    ip: {0, 0, 0, 0, 0, 0, 0, 0}
  ],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :tiser, Tiser.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "tiser_dev",
  hostname: "localhost",
  pool_size: 10

config :tiser, Tiser.Repo2,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "jianpan_dev",
  hostname: "localhost",
  pool_size: 10
