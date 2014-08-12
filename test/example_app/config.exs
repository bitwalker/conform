use Mix.Config

config :test,
  env: :wat,
  "debug_level": {:on, [:passive]}

config :sasl,
  errlog_type: :error

config :logger,
  format: "$time $metadata[$level] $levelpad$message\n"

import_config "config.#{Mix.env}.exs"
