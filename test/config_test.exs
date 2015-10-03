defmodule ConfigTest do
  use ExUnit.Case, async: true
  alias Conform.Schema
  alias Conform.Schema.Mapping

  test "can load config.exs containing nested lists" do
    path   = Path.join(["test", "configs", "nested_list.exs"])
    config = path |> Mix.Config.read!
    assert [my_app: [sublist: [[opt1: "val1", opt2: "val4"], [opt1: "val3", opt2: "val4"]],
                     rx_pattern: [~r/[A-Z]+/]]] == config
  end

  test "can translate config.exs containing nested lists to schema" do
    path   = Path.join(["test", "configs", "nested_list.exs"])
    config = path |> Mix.Config.read! |> Macro.escape
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

  test "can translate config.exs + schema + conf with nested lists to sys.config" do
    path   = Path.join(["test", "configs", "nested_list.exs"])
    config = path |> Mix.Config.read! |> Macro.escape
    schema = Conform.Schema.from_config(config)
    {:ok, conf} = Path.join(["test", "confs", "nested_list.conf"]) |> Conform.Conf.from_file
    sysconfig = Conform.Translate.to_config(schema, config, conf)
    assert [my_app: [rx_pattern: [~r/[A-Z]+/],
                     sublist: [[opt1: "val1", opt2: "val two"], [opt1: "val3", opt2: "val-4"]]]] == sysconfig
  end
end
