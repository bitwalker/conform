defmodule ConfParseTest do
  use ExUnit.Case, async: true

  test "can parse a valid conf file" do
    path = Path.join(["test", "confs", "test.conf"]) |> Path.expand
    conf = path |> Conform.Parse.file!
    assert [
      {['log','error','file'], ['/var/log/error.log']},
      {['log','console','file'],['/var/log/console.log']},
      {['log','syslog'], ['on']},
      {['sasl','errlog_type'], ['error']},
      {['myapp','some_val'], ['foo']},
      {['some', 'string value'],  ['stringkeys']},
      {['starting string', 'key'],  ['stringkeys']},
      {['myapp', 'Custom', 'Enum'],  ['prod']}
    ] == conf
  end

  test "can parse string values containing newlines" do
    path = Path.join(["test", "confs", "strings.conf"]) |> Path.expand
    conf = path |> Conform.Parse.file!
    assert [{['logger', 'format'], ['$time $metadata[$level] $levelpad$message\\n']},
            {['logger', 'values'], ['error', 'random_-\\\\alkjda;k__23232']}] == conf
  end

  test "can parse nested lists" do
    conf = "app.nested_lists = [opt1 = val1, opt2 = \"val two\"]"
    result = Conform.Parse.parse!(conf)
    assert [{['app', 'nested_lists'], [[{'opt1', 'val1'}, {'opt2', 'val two'}]]}] == result

    conf = "app.nested_lists = [opt1 = val1, opt2 = \"val two\"], [opt1 = val3, opt2 = \"val4\"]"
    result = Conform.Parse.parse!(conf)
    assert [{['app', 'nested_lists'], [[{'opt1', 'val1'}, {'opt2', 'val two'}], [{'opt1', 'val3'}, {'opt2', 'val4'}]]}] == result
  end

  test "can parse nested lists which are not key/value pairs" do
    result = Conform.Parse.file!(Path.join([__DIR__, "confs", "evl_daemon.conf"]))
    assert [{['evl_daemon', 'mailer_api_key'], ['SECRET API KEY']},
            {['evl_daemon', 'host'], ['127.0.0.1']},
            {['evl_daemon', 'port'], ['4025']},
            {['evl_daemon', 'password'], ['EVL portal password']},
            {['evl_daemon', 'auto_connect'], ['true']},
            {['evl_daemon', 'event_notifiers'], [[{'type', 'console'}],
                                                 [{'type', 'email'},
                                                  {'recipient', 'user@example.com'},
                                                  {'sender', 'noreply@example.com'}],
                                                 [{'type', 'sms'},
                                                  {'from', '+12345678'},
                                                  {'to', '+19876543'},
                                                  {'sid', 'SID'},
                                                  {'auth_token', 'Twilio AUTH TOKEN'}]]},
            {['evl_daemon', 'storage_engines'], [[{'type', 'memory'},
                                                  {'maximum_events', '100'}],
                                                 [{'type', 'dummy'}]]},
            {['evl_daemon', 'zones'], [['1', 'Front door'],
                                       ['2', 'Garage door'],
                                       ['3', 'Basement door'],
                                       ['4', 'Kitchen door'],
                                       ['5', 'Office motion sensor'],
                                       ['6', 'Family room motion sensor'],
                                       ['7', 'Basement glass break sensor'],
                                       ['8', 'Basement motion sensor']]},
            {['evl_daemon', 'partitions'], [['1', 'Main']]},
            {['evl_daemon', 'system_emails_sender'], ['noreply@example.com']},
            {['evl_daemon', 'system_emails_recipient'], ['user@example.com']},
            {['evl_daemon', 'log_level'], ['info']},
            {['evl_daemon', 'auth_token'], ['SECRET']}] == result
  end

  test "parsing utf8 should succeed" do
    conf = Conform.Parse.parse!("setting = thingŒ\n")
    assert [{['setting'], [_]}] = conf
  end
end
