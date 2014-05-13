defmodule ConfTranslateTest do
  use ExUnit.Case

  test "can generate default conf from schema" do
    path   = Path.join(["test", "schemas", "test.schema.exs"])
    schema = path |> Conform.Schema.load
    conf   = schema |> Conform.Translate.to_conf
    assert conf == """
    # The location of the error log. Should be a full path, i.e. /var/log/error.log.
    log.error.file = /var/log/error.log

    # The location of the console log. Should be a full path, i.e. /var/log/console.log.
    log.console.file = /var/log/console.log

    # This setting determines whether to use syslog or not. Valid values are :on and :off.
    log.syslog = on

    # Restricts the error logging performed by the specified 
    # sasl_error_logger to error reports, progress reports, or 
    # both. Default is all.
    sasl.log.level = all

    # Just some atom.
    myapp.some_val = foo

    # Determine the type of thing.
    # * active: it's going to be active
    # * passive: it's going to be passive
    # * active-debug: it's going to be active, with verbose debugging information
    myapp.another_val = active

    """
  end

  test "can generate config as Elixir terms from conf and schema" do
    path   = Path.join(["test", "schemas", "test.schema.exs"])
    schema = path |> Conform.Schema.load
    conf   = schema |> Conform.Translate.to_conf
    parsed = Conform.Parse.parse(conf)
    config = Conform.Translate.to_config(parsed, schema)
    expect = [
      sasl:  [errlog_type: :all],
      myapp: [
        another_val: {:on, []},
        some_val: :foo
      ],
      log: [
        console_file: "/var/log/console.log",
        error_file:   "/var/log/error.log",
        syslog: :on
      ]
    ]
    assert Keyword.equal?(expect, config)
  end

  test "can write config to disk as Erlang terms in valid app/sys.config format" do
    path   = Path.join(["test", "schemas", "test.schema.exs"])
    schema = path |> Conform.Schema.load
    conf   = schema |> Conform.Translate.to_conf
    parsed = Conform.Parse.parse(conf)
    config = Conform.Translate.to_config(parsed, schema)

    config_path = Path.join(System.tmp_dir!, "conform_test.config")
    :ok    = config_path |> Conform.Config.write(config)
    result = config_path |> List.from_char_data! |> :file.consult
    config_path |> File.rm!
    assert {:ok, [^config]} = result
  end
end