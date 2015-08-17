defmodule ConfigTest do
  use ExUnit.Case, async: true

  test "can load config.exs containing nested lists" do
    path   = Path.join(["test", "configs", "nested_list.exs"])
    config = path |> Mix.Config.read! |> Macro.escape
    assert [my_app: [sublist: [[opt1: "val1", opt2: "val4"],
              [opt1: "val3", opt2: "val4"]]]] == config
  end

  test "can translate config.exs containing nested lists to schema" do
    path   = Path.join(["test", "configs", "nested_list.exs"])
    config = path |> Mix.Config.read! |> Macro.escape
    schema = Conform.Schema.from_config(config)
    assert [import: [],
            mappings: ["my_app.sublist": [doc: "Provide documentation for my_app.sublist here.", to: "my_app.sublist",
             datatype: [list: [list: {:atom, :binary}]], default: [[opt1: "val1", opt2: "val4"], [opt1: "val3", opt2: "val4"]]]],
            translations: []] == schema
  end

  test "can translate config.exs + schema + conf with nested lists to sys.config" do
    path   = Path.join(["test", "configs", "nested_list.exs"])
    config = path |> Mix.Config.read! |> Macro.escape
    schema = Conform.Schema.from_config(config)
    conf   = Path.join(["test", "confs", "nested_list.conf"]) |> Conform.Parse.file!
    sysconfig = Conform.Translate.to_config(config, conf, schema)
    assert [my_app: [sublist: [[opt1: "val1", opt2: "val two"], [opt1: "val3", opt2: "val-4"]]]] = sysconfig
  end
end
