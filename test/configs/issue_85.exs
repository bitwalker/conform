use Mix.Config

config :rocket, Rocket.Endpoint,
  url: [host: "localhost"],
  root: Path.dirname(__DIR__),
  secret_key_base: "Hoopdie doopdie doo",
  debug_errors: false,
  http: [
    dispatch: [
      {:_, [
          {"/ws",               Pixie.Adapter.Cowboy.HttpHandler, {Pixie.Adapter.Plug, []}},
          {"/messagerocket.js", :cowboy_static,                   {:file, Path.join(Path.dirname(__DIR__),"priv/static/messagerocket.js")}},
          {:_,                  Plug.Adapters.Cowboy.Handler,     {Rocket.Endpoint, []}}
        ]
      }
    ]
  ]
