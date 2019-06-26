defmodule IntegrationTest do
  use ExUnit.Case

  test "effective configuration" do
    config = Path.join(["test", "fixtures", "test_app", "config.exs"]) |> Mix.Config.read!
    {:ok, conf} = Path.join(["test", "fixtures", "test_app", "test.conf"]) |> Conform.Conf.from_file
    schema = Path.join(["test", "fixtures", "test_app", "test.schema.exs"]) |> Conform.Schema.load!

    proxy = [{:default_route, {{127,0,0,1}, 1813, "secret"}},
             {:options, [{:type, :realm}, {:strip, true}, {:separator, '@'}]},
             {:routes, [{'test', {{127,0,0,1}, 1815, "secret"}}]}]
    effective = Conform.Translate.to_config(schema, config, conf)
    expected = [logger: [format: "$time $metadata[$level] $levelpad$message\n"],
                sasl: [errlog_type: :error],
                test: [
                  another_val: :none,
                  debug_level: :info,
                  env: :test,
                  servers: [proxy: [{ {:eradius_proxy, 'proxy', proxy}, [{'127.0.0.1', "secret"}] }]]]]
    assert Conform.Utils.sort_kwlist(effective) == expected
    assert Keyword.equal?(expected, effective)
  end

  #test "merging and stringifying master/dep schemas" do
    #master = Path.join(["test", "schemas", "merge_master.schema.exs"]) |> Conform.Schema.parse!
    #dep    = Path.join(["test", "schemas", "merge_dep.schema.exs"]) |> Conform.Schema.parse!
    #saved  = Path.join(["test", "schemas", "merged_schema.exs"])

    # Get schemas from all dependencies
    #schema   = Conform.Schema.coalesce([dep, master])
    #contents = schema |> Conform.Schema.stringify
    #saved |> File.write!(contents)

    #expected = File.read!(saved)
    #assert expected == contents
  #end

  test "can accumulate values in transforms" do
    {:ok, conf} = Path.join(["test", "confs", "lager_example.conf"]) |> Conform.Conf.from_file
    schema = Path.join(["test", "schemas", "merge_master.schema.exs"]) |> Conform.Schema.load!

    effective = Conform.Translate.to_config(schema, [], conf)
    expected  = [lager: [
                  handlers: [
                    lager_console_backend: :info,
                    lager_file_backend: [file: "/var/log/error.log", level: :error],
                    lager_file_backend: [file: "/var/log/console.log", level: :info]
                  ]],
                 myapp: [
                  some: [important: [setting: [
                    {"127.0.0.1", "80"}, {"127.0.0.2", "81"}
                  ]]]]]
    assert Conform.Utils.sort_kwlist(effective) == expected
  end

  test "for the complex data types" do
    {:ok, conf} = Path.join(["test", "confs", "complex_example.conf"]) |> Conform.Conf.from_file
    schema = Path.join(["test", "schemas", "complex_schema.exs"]) |> Conform.Schema.load!
    effective = Conform.Translate.to_config(schema, [], conf)
    expected = [my_app:
                [complex_another_list:
                 [first: [age: 20, username: "test_username1"],
                  second: [age: 40, username: "test_username2"]],
                 complex_list: [
                   buzz: [age: 25, type: :person], fido: [type: :dog]],
                 some_val: :foo, some_val2: 2.5,
                 sublist: ["opt-2": "val2", opt1: "val1"]]]

    assert Conform.Utils.sort_kwlist(effective) == expected
  end

  test "test for the custom data type" do
    {:ok, conf} = Path.join(["test", "confs", "test.conf"]) |> Conform.Conf.from_file
    schema = Path.join(["test", "schemas", "test.schema.exs"]) |> Conform.Schema.load!
    effective = Conform.Translate.to_config(schema, [], conf)
    expected =  [log:
                 [console_file: "/var/log/console.log",
                  error_file: "/var/log/error.log",
                  syslog: :on], logger:
                 [format: "$time $metadata[$level] $levelpad$message\n"],
                 myapp: [
                   {Custom.Enum, :prod},
                   {Some.Module, [val: :foo]},
                   {:another_val, {:on, [data: %{log: :warn}]}},
                   {:db, [hosts: [{"127.0.0.1", "8001"}]]}, {:some_val, :bar}, {:volume, 1}],
                 sasl: [errlog_type: :all],
                 some: ["string value": 'stringkeys'],
                 "starting string": [key: 'stringkeys']]

    assert Conform.Utils.sort_kwlist(effective) == expected
  end

  test "can generate default schema from config" do
    config_path = Path.join(["test", "configs", "nested_list.exs"])
    config = Mix.Config.read!(config_path)
    schema = Conform.Schema.from_config(config)
    result = Conform.Schema.stringify(schema, false)
    assert """
    [
      extends: [],
      import: [],
      mappings: [
        "my_app.rx_pattern": [
          commented: false,
          datatype: [
            list: :binary
          ],
          default: [
            ~r/[A-Z]+/
          ],
          doc: "Provide documentation for my_app.rx_pattern here.",
          hidden: false,
          to: "my_app.rx_pattern"
        ],
        "my_app.sublist": [
          commented: false,
          datatype: [
            list: [
              list: {:atom, :binary}
            ]
          ],
          default: [
            [opt1: "val1", opt2: "val4"],
            [opt1: "val3", opt2: "val4"]
          ],
          doc: "Provide documentation for my_app.sublist here.",
          hidden: false,
          to: "my_app.sublist"
        ]
      ],
      transforms: [],
      validators: []
    ]
    """ |> String.strip(?\n) == result
  end

end
