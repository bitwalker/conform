defmodule IntegrationTest do
  use ExUnit.Case, async: true

  test "test effective configuration" do
    config = Path.join(["test", "example_app", "config.exs"]) |> Mix.Config.read!
    conf   = Path.join(["test", "example_app", "test.conf"]) |> Conform.Parse.file
    schema = Path.join(["test", "example_app", "test.schema.exs"]) |> Conform.Schema.load!

    effective = Conform.Translate.to_config(config, conf, schema)
    expected = [logger: [format: "$time $metadata[$level] $levelpad$message\n"],
                sasl: [errlog_type: :error],
                test: [
                  another_val: :none,
                  debug_level: :info,
                  env: :test]]
    assert Keyword.equal?(expected, effective)
  end

  test "test merging and stringifying master/dep schemas" do
    master = Path.join(["test", "schemas", "merge_master.schema.exs"]) |> Conform.Schema.read!
    dep    = Path.join(["test", "schemas", "merge_dep.schema.exs"]) |> Conform.Schema.read!
    saved  = Path.join(["test", "schemas", "merged_schema.exs"])

    # Get schemas from all dependencies
    schema   = Conform.Schema.coalesce([dep, master])
    contents = schema |> Conform.Schema.stringify
    saved |> File.write!(contents)

    expected = File.read!(saved)
    assert expected == contents
  end

  test "can accumulate values in transforms" do
    conf   = Path.join(["test", "confs", "lager_example.conf"]) |> Conform.Parse.file
    schema = Path.join(["test", "schemas", "merge_master.schema.exs"]) |> Conform.Schema.load

    effective = Conform.Translate.to_config([], conf, schema)
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
    assert Keyword.equal?(expected, effective)
  end

  test "test for the complex data types" do
    conf   = Path.join(["test", "confs", "complex_example.conf"]) |> Conform.Parse.file
    schema = Path.join(["test", "schemas", "complex_schema.exs"]) |> Conform.Schema.load
    effective = Conform.Translate.to_config([], conf, schema)
    expected = [my_app:
                [complex_another_list:
                 [first: %{age: 20, username: "test_username1"},
                  second: %{age: 40, username: "test_username2"}],
                 complex_list: [
                   buzz: %{age: 25, type: :person}, fido: %{age: 30, type: :dog}],
                 some_val: :foo, some_val2: 2.5]]

    assert effective == expected
  end
end
