defmodule ConformEffectiveTest do
  use ExUnit.Case, async: true

  test "defaults and transforms" do
    config = Mix.Config.read!(Path.join([__DIR__, "configs", "readme_example.exs"]))
    {:ok, conf} = Conform.Conf.from_file(Path.join([__DIR__, "confs", "readme_example.conf"]))
    schema = Conform.Schema.load!(Path.join([__DIR__, "schemas", "readme_example.schema.exs"]))
    effective = Conform.Translate.to_config(schema, config, conf)
    expected = 40
    assert ^expected = get_in(effective, [:my_app, :max_demand])
  end

  test "issue #112" do
    config = Mix.Config.read!(Path.join([__DIR__, "configs", "evl_daemon.exs"]))
    {:ok, conf} = Conform.Conf.from_file(Path.join([__DIR__, "confs", "evl_daemon.conf"]))
    schema = Conform.Schema.load!(Path.join([__DIR__, "schemas", "evl_daemon.schema.exs"]))
    effective = Conform.Translate.to_config(schema, config, conf)
    assert [evl_daemon: [{EvlDaemon.Mailer, adapter: Bamboo.SendgridAdapter, api_key: "SECRET API KEY"},
                         auth_token: "SECRET",
                         auto_connect: true,
                         event_notifiers: [[type: "console"],
                                           [type: "email", recipient: "user@example.com", sender: "noreply@example.com"],
                                           [type: "sms", from: "+12345678", to: "+19876543", sid: "SID", auth_token: "Twilio AUTH TOKEN"]],
                         host: '127.0.0.1',
                         partitions: %{"1" => "Main"},
                         password: "EVL portal password",
                         port: 4025,
                         storage_engines: [[type: "memory", maximum_events: "100"],
                                           [type: "dummy"]],
                         system_emails_recipient: "user@example.com",
                         system_emails_sender: "noreply@example.com",
                         zones: %{"001" => "Front door",
                                  "002" => "Garage door",
                                  "003" => "Basement door",
                                  "004" => "Kitchen door",
                                  "005" => "Office motion sensor",
                                  "006" => "Family room motion sensor",
                                  "007" => "Basement glass break sensor",
                                  "008" => "Basement motion sensor"}],
            logger: [level: :info]] == effective
  end
end
