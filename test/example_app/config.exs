use Mix.Config

config :test,
  env: :wat,
  "debug_level": {:on, [:passive]}

config :sasl,
  errlog_type: :error

import_config "config.#{Mix.env}.exs"
