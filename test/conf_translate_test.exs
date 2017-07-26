defmodule ConfTranslateTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  test "can generate default conf from schema" do
    path   = Path.join(["test", "schemas", "test.schema.exs"])
    schema = path |> Conform.Schema.load!
    conf   = schema |> Conform.Translate.to_conf
    expected = """
    # The location of the error log. Should be a full path, i.e. /var/log/error.log.
    log.error.file = "/var/log/error.log"

    # The location of the console log. Should be a full path, i.e. /var/log/console.log.
    log.console.file = "/var/log/console.log"

    # This setting determines whether to use syslog or not. Valid values are :on and :off.
    # Allowed values: on, off
    log.syslog = on

    # Restricts the error logging performed by the specified
    # `sasl_error_logger` to error reports, progress reports, or
    # both. Default is all. Just testing "nested strings".
    # Allowed values: error, progress, all
    sasl.log.level = all

    # The format to use for Logger.
    logger.format = "$time $metadata[$level] $levelpad$message\n"

    # Remote db hosts
    myapp.db.hosts = 127.0.0.1:8001

    # Just some atom.
    myapp.some_val = foo

    # Example of quoted keys
    "starting string".key = empty

    # Determine the type of thing.
    # * active: it's going to be active
    # * passive: it's going to be passive
    # * active-debug: it's going to be active, with verbose debugging information
    # Allowed values: active, passive, active-debug
    myapp.another_val = active

    # Atom module name
    myapp.Some.Module.val = foo

    # Provide documentation for myapp.Custom.Enum here.
    # Allowed values: dev, prod, test
    myapp.Custom.Enum = dev

    # The volume of some thing. Valid values are 1-11.
    myapp.volume = 1

    """

    assert expected == conf
  end

  test "can generate config as Elixir terms from .conf and schema with imports" do
    cwd = File.cwd!
    script = Path.join([cwd, "priv", "bin", "conform"])
    example_app_path = Path.join([cwd, "test", "fixtures", "example_app"])
    sys_config_dir = Path.join([cwd, "test", "fixtures", "example_app", "config"])
    sys_config_path = Path.join(sys_config_dir, "sys.config")
    conf_path = Path.join([cwd, "test", "fixtures", "example_app", "config", "test.conf"])
    schema_path = Path.join([cwd, "test", "fixtures", "example_app", "config", "test.schema.exs"])

    File.touch(sys_config_path)
    capture_io(fn ->
      {:ok, zip_path, _build_files} =
        Mix.Project.in_project(:example_app, example_app_path,
          fn _ ->
            Mix.Task.run("deps.get")
            Mix.Task.run("deps.compile")
            Mix.Task.run("compile")
            Mix.Task.run("conform.archive", [schema_path])
          end)

      expected = [
        fake_app: [greeting: "hi!"],
        test: [another_val: 3, debug_level: :info, env: :prod]
      ]

      _ = Mix.Task.run("escript.build", ["--force"])
      {_output, 0} = System.cmd(script, ["--schema", schema_path, "--conf", conf_path, "--output-dir", sys_config_dir])
      {:ok, [sysconfig]} = :file.consult(sys_config_path)
      assert "test.schema.ez" = Path.basename(zip_path)
      assert ^expected = Conform.Utils.sort_kwlist(sysconfig)
      File.rm(sys_config_path)
    end)
  end

  test "can handle utf8 values when translating" do
    cwd = File.cwd!
    script = Path.join([cwd, "priv", "bin", "conform"])
    sys_config = Mix.Config.read!(Path.join([cwd, "test", "configs", "utf8.exs"]))
    utf8_dir = Path.join([cwd, "test", "fixtures", "utf8"])
    File.mkdir_p!(utf8_dir)
    sys_config_path = Path.join([utf8_dir, "utf8_sys.config"])
    :ok = Conform.SysConfig.write(sys_config_path, sys_config)
    conf_path = Path.join([cwd, "test", "confs", "utf8.conf"])
    schema_path = Path.join([cwd, "test", "schemas", "utf8.schema.exs"])

    #capture_io(fn ->
      expected = [my_app: [utf8: "Fixé"]]

      _ = Mix.Task.run("escript.build", ["--force"])
      {_output, 0} = System.cmd(script, ["--schema", schema_path, "--conf", conf_path, "--output-dir", utf8_dir])
      {:ok, [sysconfig]} = :file.consult(Path.join([utf8_dir, "sys.config"]))
      assert ^expected = sysconfig
      File.rm_rf!(utf8_dir)
    #end)
  end

  test "can generate config as Elixir terms from .conf and schema" do
    path   = Path.join(["test", "schemas", "test.schema.exs"])
    schema = path |> Conform.Schema.load!
    {:ok, conf} = schema |> Conform.Translate.to_conf |> Conform.Conf.from_binary
    config = Conform.Translate.to_config(schema, [], conf)
    expect = [
      log: [
        console_file: "/var/log/console.log",
        error_file:   "/var/log/error.log",
        syslog: :on
      ],
      logger: [format: "$time $metadata[$level] $levelpad$message\n"],
      myapp: [
        {Custom.Enum, :dev},
        {Some.Module, [val: :foo]},
        another_val: {:on, [data: %{log: :warn}]},
        db: [hosts: [{"127.0.0.1", "8001"}]],
        some_val: :bar,
        volume: 1
      ],
      sasl:  [errlog_type: :all],
      some: ["string value": nil],
      "starting string": [key: 'empty']
    ]
    assert Conform.Utils.sort_kwlist(config) == expect
  end

  test "can generate config as Elixir terms from existing config, .conf and schema" do
    config = [sasl: [errlog_type: :error], log: [syslog: :off]]
    path   = Path.join(["test", "schemas", "test.schema.exs"])
    schema = Conform.Schema.load!(path)
    conf = """
    # Restricts the error logging performed by the specified
    # `sasl_error_logger` to error reports, progress reports, or
    # both. Default is all. Just testing "nested strings".
    sasl.log.level = progress

    # Determine the type of thing.
    # * active: it's going to be active
    # * passive: it's going to be passive
    # * active-debug: it's going to be active, with verbose debugging information
    myapp.another_val = active
    """
    {:ok, parsed} = Conform.Conf.from_binary(conf)
    config = Conform.Translate.to_config(schema, config, parsed)
    expect = [
      log: [
        console_file: "/var/log/console.log",
        error_file:   "/var/log/error.log",
        syslog: :on
      ],
      logger: [format: "$time $metadata[$level] $levelpad$message\n"],
      myapp: [
        {Custom.Enum, :dev},
        {Some.Module, [val: :foo]},
        another_val: {:on, [data: %{log: :warn}]},
        db: [hosts: [{"127.0.0.1", "8001"}]],
        some_val: :bar,
        volume: 1
      ],
      sasl:  [errlog_type: :progress],
      some: ["string value": nil],
      "starting string": [key: 'empty']
    ]
    assert Conform.Utils.sort_kwlist(config) == expect
  end

  test "can write config to disk as Erlang terms in valid app/sys.config format" do
    path   = Path.join(["test", "schemas", "test.schema.exs"])
    schema = Conform.Schema.load!(path)
    conf   = Conform.Translate.to_conf(schema)
    {:ok, parsed} = Conform.Conf.from_binary(conf)
    config = Conform.Translate.to_config(schema, [], parsed)

    config_path = Path.join(System.tmp_dir!, "conform_test.config")
    :ok    = config_path |> Conform.SysConfig.write(config)
    result = config_path |> String.to_char_list |> :file.consult
    config_path |> File.rm!
    assert {:ok, [^config]} = result
  end

  test "can translate with nested lists to conf" do
    path   = Path.join(["test", "configs", "nested_list.exs"])
    config = path |> Mix.Config.read!
    schema = Conform.Schema.from_config(config)
    conf   = Conform.Translate.to_conf(schema)
    expected = """
    # Provide documentation for my_app.sublist here.
    my_app.sublist = [opt1 = \"val1\", opt2 = \"val4\"], [opt1 = \"val3\", opt2 = \"val4\"]

    # Provide documentation for my_app.rx_pattern here.
    my_app.rx_pattern = ~r/[A-Z]+/

    """
    assert expected == conf
  end
end
