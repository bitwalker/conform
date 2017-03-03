use Mix.Config

config :pooler, pools: [
  [
    name: :riaklocal1,
    group: :riak,
    max_count: 10,
    init_count: 9,
    start_mfa: {Riak.Connection, :start_link, ['127.0.0.1', 8087]}
  ]
]
