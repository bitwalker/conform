defmodule ConfParseTest do
  use ExUnit.Case

  test "can parse a valid conf file" do
    path = Path.join(["test", "confs", "test.conf"]) |> Path.expand
    conf = path |> Conform.Parse.file
    assert [
      {['log','error','file'],'/var/log/error.log'},
      {['log','console','file'],'/var/log/console.log'},
      {['log','syslog'],'on'},
      {['sasl','errlog_type'],'error'},
      {['myapp','some_val'],'foo'}
    ] == conf
  end

  test "fail to parse utf8" do
    conf = Conform.Parse.parse("setting = thingŒ\n")
    assert [{['setting'], {:error, 'Error converting value on line #1 to latin1'}}] == conf
  end
end