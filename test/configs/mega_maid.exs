use Mix.Config

config :mega_maid, MegaMaid.Endpoint,
 render_errors: [accepts: ["html","json"]],
 pubsub: [name: MegaMaid.PubSub,
          adapter: Phoenix.PubSub.PG2],
  http: [compress: true, port: {:system, "PORT"}],
  url: [host: nil, scheme: "https", port: 443],
  root: ".",
  check_origin: ["//"],
  cache_static_manifest: "priv/static/manifest.json",
  secret_key_base: nil,
  server: true,
  root: ".",
  version: "1.6.5"
