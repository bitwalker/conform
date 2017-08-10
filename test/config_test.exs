defmodule ConfigTest do
  use ExUnit.Case, async: true
  alias Conform.Schema
  alias Conform.Schema.Mapping

  test "README example" do
    schema_path = Path.join(["test", "schemas", "readme_example.schema.exs"])
    schema = Conform.Schema.load!(schema_path)
    conf_path = Path.join(["test", "confs", "readme_example.conf"])
    {:ok, conf} = Conform.Conf.from_file(conf_path)
    config_path = Path.join(["test", "configs", "readme_example.exs"])
    config = Mix.Config.read!(config_path)
    sysconfig = Conform.Translate.to_config(schema, config, conf)
    expected = [evl_daemon: [storage_engines: [[type: "memory", maximum_events: "100"]]],
     lager: [
         handlers: [
             lager_console_backend: :info,
             lager_file_backend: [file: "/var/log/console.log", level: :info],
             lager_file_backend: [file: "/var/log/error.log",    level: :error]
           ]],
     my_app: [
         another_val: {:on, [{:debug, true}, {:tracing, true}]},
         complex_list: [first: [age: 20, username: "username1"],
                        second: [age: 40, username: "username2"]],
         db: [hosts: [{"127.0.0.1", "8000"}, {"127.0.0.2", "8001"}]],
         max_demand: 40,
         nodelist: [:'a@bar', :'b@bar'],
         some_val: :foo
       ]]
    assert expected == Conform.Utils.sort_kwlist(sysconfig)
  end

  test "issue #85" do
    path = Path.join(["test", "configs", "issue_85.exs"])
    output_path = Path.join(["test", "configs", "issue_85.schema.exs"])
    config_raw = path |> Mix.Config.read!
    config = path |> Mix.Config.read!
    assert [rocket: _] = config

    schema = Conform.Schema.from_config(config_raw)
    assert %Schema{} = schema
    assert :ok = Conform.Schema.write_quoted(schema, output_path)
    File.rm!(output_path)
  end

  test "issue #114" do
    path = Path.join(["test", "configs", "issue_114.exs"])
    output_path = Path.join(["test", "configs", "issue_114.schema.exs"])
    config_raw = path |> Mix.Config.read!

    schema = Conform.Schema.from_config(config_raw)
    assert %Schema{} = schema
    assert :ok = Conform.Schema.write_quoted(schema, output_path)
    assert %Schema{} = Conform.Schema.load!(output_path)
    File.rm!(output_path)
  end

  test "issue #75" do
    path = Path.join(["test", "configs", "raw_binary.exs"])
    output_path = Path.join(["test", "configs", "raw_binary.schema.exs"])
    config_raw = path |> Mix.Config.read!
    config = path |> Mix.Config.read!

    assert [my_app: _] = config
    schema = Conform.Schema.from_config(config_raw)
    assert %Schema{} = schema
    assert :ok = Conform.Schema.write_quoted(schema, output_path)
    File.rm!(output_path)
  end

  test "issue #113" do
    schema_path   = Path.join(["test", "schemas", "mega_maid.schema.exs"])
    schema = schema_path |> Conform.Schema.load!
    config = Mix.Config.read!(Path.join(["test", "configs", "mega_maid.exs"]))
    conf_path = Path.join(["test", "confs", "mega_maid.conf"])
    {:ok, conf} = Conform.Conf.from_file(conf_path)
    sysconfig = Conform.Translate.to_config(schema, config, conf)
    assert is_list(sysconfig)
  end

  test "logger example" do
    path = Path.join(["test", "configs", "logger.exs"])
    config_raw = path |> Mix.Config.read!
    config = path |> Mix.Config.read!
    assert [logger: [backends: [:console, {ExSyslog, :exsyslog_error}, {ExSyslog, :exsyslog_debug}]]] = config
    schema = Conform.Schema.from_config(config_raw)

    assert %Schema{extends: [], import: [],
                   mappings: [%Mapping{
                                 name: "logger.backends",
                                 commented: false,
                                 datatype: [list: [:atom, {:atom, :atom}]],
                                 default: [
                                   :console,
                                   {ExSyslog, :exsyslog_error},
                                   {ExSyslog, :exsyslog_debug}
                                 ],
                                 doc: "Provide documentation for logger.backends here.",
                                 hidden: false,
                                 to: "logger.backends"
                              }]} = schema

    conf_str = Conform.Translate.to_conf(schema)
    {:ok, conf} = Conform.Conf.from_binary(conf_str)
    sysconfig = Conform.Translate.to_config(schema, config, conf)
    assert [logger: [backends: [:console, {ExSyslog, :exsyslog_error}, {ExSyslog, :exsyslog_debug}]]] = sysconfig
  end

  test "can translate config.exs containing nested lists to schema" do
    path   = Path.join(["test", "configs", "nested_list.exs"])
    config = path |> Mix.Config.read!
    schema = Conform.Schema.from_config(config)
    assert %Schema{extends: [], import: [],
            mappings: [%Mapping{
              name: "my_app.sublist",
              doc: "Provide documentation for my_app.sublist here.",
              to: "my_app.sublist",
              datatype: [list: [list: {:atom, :binary}]],
              default: [[opt1: "val1", opt2: "val4"], [opt1: "val3", opt2: "val4"]]
            },
            %Mapping{
              name: "my_app.rx_pattern",
              doc: "Provide documentation for my_app.rx_pattern here.",
              to: "my_app.rx_pattern",
              datatype: [list: :binary],
              default: [~r/[A-Z]+/]
            }],
            transforms: []} == schema
  end

  test "can translate config.exs containing a single nested list to schema" do
    path   = Path.join(["test", "configs", "single_nested_list.exs"])
    config = path |> Mix.Config.read!
    schema = Conform.Schema.from_config(config)
    assert %Schema{extends: [], import: [],
                   mappings: [%Mapping{
                                 name: "my_app.sublist",
                                 doc: "Provide documentation for my_app.sublist here.",
                                 to: "my_app.sublist",
                                 datatype: [list: [list: {:atom, :binary}]],
                                 default: [[opt1: "val1", opt2: "val4"]]
                          },
                              %Mapping{
                                name: "my_app.rx_pattern",
                                doc: "Provide documentation for my_app.rx_pattern here.",
                                to: "my_app.rx_pattern",
                                datatype: [list: :binary],
                                default: [~r/[A-Z]+/]
                              }],
                   transforms: []} == schema
  end

  test "can translate config.exs + schema + conf with nested lists to sys.config" do
    path   = Path.join(["test", "configs", "nested_list.exs"])
    config_raw = path |> Mix.Config.read!
    config = path |> Mix.Config.read!
    schema = Conform.Schema.from_config(config_raw)
    {:ok, conf} = Path.join(["test", "confs", "nested_list.conf"]) |> Conform.Conf.from_file
    sysconfig = Conform.Translate.to_config(schema, config, conf)
    assert [my_app: [rx_pattern: [~r/[A-Z]+/],
                     sublist: [[opt1: "val1", opt2: "val two"], [opt1: "val3", opt2: "val-4"]]]] == sysconfig
  end

  test "raises runtime error if env var value is missing and there is no default value" do
    schema_path = Path.join(["test", "schemas", "env_var.schema.exs"])
    schema = Conform.Schema.load!(schema_path)
    conf_path = Path.join(["test", "confs", "test.conf"])
    {:ok, conf} = Conform.Conf.from_file(conf_path)

    assert_raise RuntimeError, ~r/^Configuration Error/, fn ->
      Conform.Translate.to_config(schema, [], conf)
    end
  end
end
