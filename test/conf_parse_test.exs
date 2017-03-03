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

  test "parsing utf8 should succeed" do
    conf = Conform.Parse.parse!("setting = thingŒ\n")
    assert [{['setting'], [_]}] = conf
  end
end
