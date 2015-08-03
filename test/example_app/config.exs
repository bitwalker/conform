use Mix.Config

proxy = [{:default_route, {{127,0,0,1}, 1813, "secret"}},
         {:options, [{:type, :realm}, {:strip, true}, {:separator, '@'}]},
         {:routes, [{'test', {{127,0,0,1}, 1815, "secret"}}]}]

config :test,
  env: :wat,
  "debug_level": {:on, [:passive]}

config :test, :servers,
  proxy: [{ {:eradius_proxy, 'proxy', proxy}, [{'127.0.0.1', "secret"}] }]

config :sasl,
  errlog_type: :error

config :logger,
  format: "$time $metadata[$level] $levelpad$message\n"

import_config "config.#{Mix.env}.exs"
