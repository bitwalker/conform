defmodule ConformCodeTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  test "can stringify function and case blocks" do
    source = """
    [transforms: [
      "single_clause": fn val ->
        case val do
          foo when foo in [:foo] ->
            bar = String.to_atom("bar")
            bar
          bar when bar != :baz ->
            baz = String.to_atom(bar)
            baz
          :baz -> :qux
        end
      end,
      "multi_clause": fn
        :foo -> bar
        val ->
          case val do
            :baz -> :qux
            _    ->
              result = val |> String.to_atom
              result
          end
      end]]
    """
    stringified = """
    [
      transforms: [
        single_clause: fn val ->
          case val do
            foo when foo in [:foo] ->
              bar = String.to_atom("bar")
              bar
            bar when bar != :baz ->
              baz = String.to_atom(bar)
              baz
            :baz ->
              :qux
          end
        end,
        multi_clause: fn
          :foo ->
            bar
          val ->
            case val do
              :baz ->
                :qux
              _ ->
                result = val |> String.to_atom()
                result
            end
        end
      ]
    ]
    """ |> String.strip(?\n)

    {:ok, quoted} = Code.string_to_quoted(source)
    assert stringified == Conform.Utils.Code.stringify(quoted)
  end

  test "can stringify strings" do
    singleline      = "Doing stuff and things."
    single_expected = "\"Doing stuff and things.\""
    multiline  = """
    Determine the type of thing.
    * active: it's going to be active
    * passive: it's going to be passive
    * active-debug: it's going to be active, with verbose debugging information
    Just testing "nested quotes"
    """
    multi_expected = """
    \"\"\"
    Determine the type of thing.
    * active: it's going to be active
    * passive: it's going to be passive
    * active-debug: it's going to be active, with verbose debugging information
    Just testing "nested quotes"
    \"\"\"
    """ |> String.strip(?\n)

    {:ok, singleline_quoted} = singleline |> Macro.to_string |> Code.string_to_quoted
    {:ok, multiline_quoted}  = multiline |> Macro.to_string |> Code.string_to_quoted
    assert single_expected == (singleline_quoted |> Conform.Utils.Code.stringify)
    assert multi_expected  == (multiline_quoted |> Conform.Utils.Code.stringify)
  end

  test "can stringify complex datastructures" do
    data = """
    ["myapp.another_val": [
      to:       "myapp.another_val",
      datatype: [enum: [:active, :passive, :'active-debug']],
      default:  %{test: :foo},
      doc: \"\"\"
      Determine the type of thing.
      * active: it's going to be active
      * passive: it's going to be passive
      * active-debug: it's going to be active, with verbose debugging information
      \"\"\"
    ],
    "myapp.some_pattern": [
       default: [~r/[A-Z]+/]
      ]]
    """

    expected = """
    [
      "myapp.another_val": [
        to: "myapp.another_val",
        datatype: [
          enum: [
            :active,
            :passive,
            :"active-debug"
          ]
        ],
        default: %{test: :foo},
        doc: \"\"\"
        Determine the type of thing.
        * active: it's going to be active
        * passive: it's going to be passive
        * active-debug: it's going to be active, with verbose debugging information
        \"\"\"
      ],
      "myapp.some_pattern": [
        default: [
          ~r/[A-Z]+/
        ]
      ]
    ]
    """ |> String.strip(?\n)

    {:ok, quoted} = data |> Code.string_to_quoted
    {schema, _} = Code.eval_quoted(quoted, file: "nofile", line: 0)
    result = (schema |> Conform.Utils.Code.stringify)
    assert expected == result
  end

  test "can stringify function/case blocks mixed with datastructures" do
    data = """
    [translations: [
      "myapp.another_val": fn
        :foo -> :bar
        val ->
          case val do
            :active ->
              data = %{log: :warn}
              more_data = %{data | :log => :warn}
              {:on, [data: data]}
            :'active-debug' -> {:on, [debug: true]}
            :passive        -> {:off, []}
            _               -> {:on, []}
          end
      end,
      "myapp.some_val": fn
        :foo -> :bar
        val ->
          case val do
            :foo -> :bar
            _    -> val
          end
      end
    ]]
    """

    expected = """
    [
      translations: [
        "myapp.another_val": fn
          :foo ->
            :bar
          val ->
            case val do
              :active ->
                data = %{log: :warn}
                more_data = %{data | log: :warn}
                {:on, [data: data]}
              :"active-debug" ->
                {:on, [debug: true]}
              :passive ->
                {:off, []}
              _ ->
                {:on, []}
            end
        end,
        "myapp.some_val": fn
          :foo ->
            :bar
          val ->
            case val do
              :foo ->
                :bar
              _ ->
                val
            end
        end
      ]
    ]
    """ |> String.strip(?\n)

    {:ok, quoted} = data |> Code.string_to_quoted
    assert expected == (quoted |> Conform.Utils.Code.stringify)
  end

  test "generating a new schema and conf from complex config should work out of the box" do
    capture_io(fn ->
      config_path = Path.join([__DIR__, "configs", "issue_122.exs"])
      schema_path = Path.join([__DIR__, "schemas", "issue_122.schema.exs"])
      conf_path = Path.join([__DIR__, "confs", "issue_122.conf"])
      File.rm(schema_path)
      File.rm(conf_path)
      config = Mix.Config.read!(config_path)
      schema = Conform.Schema.from_config(config)
      Conform.Schema.write_quoted(schema, schema_path)
      # Convert configuration to schema format
      assert %Conform.Schema{} = schema = Conform.Schema.load!(schema_path)
      # Convert to .conf
      conf = Conform.Translate.to_conf(schema)
      # Output configuration to `output_path`
      File.write!(conf_path, conf)
      File.rm(schema_path)
      File.rm(conf_path)
    end)
  end
end
