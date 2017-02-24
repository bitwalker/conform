# Conform

[![Master](https://travis-ci.org/bitwalker/conform.svg?branch=master)](https://travis-ci.org/bitwalker/conform)
[![Hex.pm Version](http://img.shields.io/hexpm/v/conform.svg?style=flat)](https://hex.pm/packages/conform)

The definition of conform is "Adapt or conform oneself to new or different conditions". As this library is used to adapt your application to its deployed environment, I think it's rather fitting. It's also a play on the word configuration, and the fact that Conform uses an init-style configuration, maintained in a `.conf` file.

Conform is a library for Elixir applications. Its original intended use is in exrm as means of providing a simplified configuration file for deployed releases, but is flexible enough to work for any use case where you want init-style configuration translated to Elixir/Erlang terms. It is inspired directly by `basho/cuttlefish`, and in fact uses its .conf parser. Beyond that, you can look at conform as a reduced (but growing!) implementation of cuttlefish in Elixir.

## Usage

You can use Conform either via its API, which is simple and easy to pick up, or by building the escript and running that via the command line.

Running the escript's help, you'll see how it's used:

```
↪ ./conform --help
Conform - Translate the provided .conf file to a .config file using the given schema
-------
usage: conform --conf foo.conf --schema foo.schema.exs [options]

Options:
  --filename <name>:    Names the output file <name>.config
  --output-dir <path>:  Outputs the .config file to <path>/<sys|name>.config
  --config <config>:    Merges the translated configuration over the top of
                        <config> before output
  -h | --help:          Prints this help
```

Conform also provides some mix tasks for generating and viewing
configuration:

- `mix conform.new` - Generates a schema from your current project
configuration
- `mix conform.configure` - Generates a default .conf from your schema
  file and current project configuration
- `mix conform.effective` - View the effective configuration for your
  release.

There are additional options for these tasks, use `mix help <task>` to view their documentation.

## Usage with Distillery

All you need to use Conform with Distillery is to set the plugin in your release config:

```elixir
release :test do
  set version: current_version(:test)

  plugin Conform.ReleasePlugin
end
```

In 2.1+, you can remove the old configuration which set the `pre_start` hook.

## Conf files and Schema files

The conform .conf file looks something like the following:

```
# Choose the logging level for the console backend.
# Allowed values: info, error
lager.handlers.console.level = info

# Specify the path to the error log for the file backend
lager.handlers.file.error = /var/log/error.log

# Specify the path to the console log for the file backend
lager.handlers.file.info = /var/log/console.log

# Remote database hosts
my_app.db.hosts = 127.0.0.1:8000, 127.0.0.2:8001

# Just some atom.
my_app.some_val = foo

# Determine the type of thing.
# * all:  use everything
# * some: use a few things
# * none: use nothing
# Allowed values: all, some, none
my_app.another_val = all

# complex data types with wildcard support
my_app.complex_list.first.username = "username1"
my_app.complex_list.first.age = 20
my_app.complex_list.second.username = "username2"
my_app.complex_list.second.age = 40
```

Short and sweet, and most importantly, easy for sysadmins and users to understand and modify. The real power of conform though is when you dig into the schema file. It allows you to define documentation, mappings between friendly setting names and specific application settings in the underlying sys.config, define validation of values via datatype specifications, provide default values, and transform simplified values from the .conf into something more meaningful to your application using translation functions.

A schema is basically a single data structure. A keyword list, containing the following top-level properties, `extends`, `import`, `mappings`, and `transforms`. Before we dive in, here's the schema for the .conf file above:

```elixir
[
  extends: [],
  import: [],
  mappings: [
    "lager.handlers.console.level": [
      doc: """
      Choose the logging level for the console backend.
      """,
      to: "lager.handlers.lager_console_backend",
      datatype: [enum: [:info, :error]],
      default: :info
    ],
    "lager.handlers.file.error": [
      doc: """
      Specify the path to the error log for the file backend
      """,
      to: "lager.handlers.lager_file_backend.error",
      datatype: :binary,
      default: "/var/log/error.log"
    ],
    "lager.handlers.file.info": [
      doc: """
      Specify the path to the console log for the file backend
      """,
      to: "lager.handlers.lager_file_backend.info",
      datatype: :binary,
      default: "/var/log/console.log"
    ],
    "my_app.db.hosts": [
      doc: "Remote database hosts",
      to: "my_app.db.hosts",
      datatype: [list: :ip],
      default: [{"127.0.0.1", "8001"}]
    ],
    "my_app.some_val": [
      doc:      "Just some atom.",
      to:       "my_app.some_val",
      datatype: :atom,
      default:  :foo
    ],
    "my_app.another_val": [
      doc: "Just another enum",
      to: "my_app.another_val",
      datatype: :atom,
      default: :none
    ],
    "my_app.complex_list.*": [
      to: "my_app.complex_list",
      datatype: [list: :complex],
      default: []
    ],
    "my_app.complex_list.*.username": [
      to: "my_app.complex_list",
      datatype: :binary,
      required: true
    ],
    "my_app.complex_list.*.age": [
      to: "my_app.complex_list",
      datatype: :integer,
      default: 30
    ]
  ],

  transforms: [
    "my_app.another_val": fn conf ->
      case Conform.Conf.get(conf, "my_app.another_val") do
        [{_, :all}]  -> {:on, [debug: true, tracing: true]}
        [{_, :some}] -> {:on, [debug: true]}
        [{_, :none}] -> {:off, []}
        _            -> {:off, []}
      end
    end,
    "lager.handlers": fn conf ->
      backends = Conform.Conf.find(conf, "lager.handlers.$backend")
      |> Enum.reduce([], fn
        {[_,_,'lager_file_backend', level], path}, acc ->
          [{:lager_file_backend, [level: :"#{level}", file: path]}|acc]
        {[_,_,'lager_console_backend'], level}, acc ->
          [{:lager_console_backend, level}|acc]
      end)
      Conform.Conf.remove(conf, "lager.handlers.$backend")
      backends
    end,
  ]
]
```

This looks pretty daunting, but I've provided mix tasks to help you generate the schema from your existing `config.exs` file. Once you've gotten the schema tightened up though, you'll start to understand why it's worth a little extra effort up front. Let's talk about the top-level properties of the schema briefly:

- `extends` allows you to extend the schema of another application in your project.
- `import` allows you to import an application's modules which contain functions you wish to use.
- `mappings` define the mapping between the .conf settings and your actual configuration keys. We'll get more into those later.
- `transforms` define transformations of mapped values for more complex configuration scenarios.

### Mappings

Mappings are defined by four key properties (there are more, just see the `Conform.Schema.Mapping` module docs):

- `:doc`, documentation on what this setting is, and how to use it
- `:to`, if you want friendly names for not so friendly app settings, `:to` tells conform what setting this mapping applies to in the generated `.config`
- `:datatype`, the datatype of the value, currently supports binary, charlist, atom, integer, float, ip (a tuple of strings `{ip, port}`), enum, and lists of one of those types.
- `:default`, optional, the value to use if one is not supplied for this setting. Should be the same form as the datatype for the setting. So for example, if you have a setting, `myapp.foo`, with a datatype of `[enum: [:info, :warn, :error]]`, then your default value should be one of those three atoms.

### Transforms

After all settings have been mapped, each of the transforms is executed with the PID of the ETS table holding the config. You will need to use the `Conform.Conf` module API to query the configuration state using this PID. The value returned from the transform is then paired with the key the transformed is defined against and used in the final configuration.

### Example Output

The following is the output configuration from conform using the .conf and .schema.exs files shown above:

```erlang
[lager: [handlers: [
             lager_console_backend: :info,
             lager_file_backend: [file: "/var/log/console.log", level: :info],
             lager_file_backend: [file: "/var/log/error.log",    level: :error]
           ]],
 my_app: [another_val: {:on, [{:debug, true}, {:tracing, true}]},
          complex_list: [first: [age: 20, username: "username1"],
                        second: [age: 40, username: "username2"]],
          db: [hosts: [{"127.0.0.1", "8000"}, {"127.0.0.2", "8001"}]],
          some_val: :foo]]
```

As you can see, if your sysadmins had to work with the above, versus the .conf, it would be quite prone to mistakes, and much harder to understand, particularly with the lack of comments or documentation.

If you are using `exrm` and need to import any applications from the `your_app/deps`, you can update your `you_app.schema.exs` with the `import`:

```elixir
[
    import: [
        :my_app_dep1,
        :my_app_dep2
    ],

    mappings: [
        ...
        ...
        ...
    ],

    transforms: [
        ...
        ...
        ...
    ]
]
```

Will be created archive with the `myapp.schema.ez` name in the your release which will contain the `my_app_dep1` and `my_app_dep2` applications. During the `sys.config` will be generated by conform script, the applications from the archive will be loaded and you can use any public API from these applications in your transforms. Conform also allows to use a schema with imports without `distillery`. There is the special `conform.archive` mix task that takes one parameter - path of the schema:

```
mix conform.archive myapp/config/myapp.schema.exs
```

`Conform` will collect dependencies which are pointed in the `import: [....]` and compress them to the `myapp/config/myapp.schema.ez` archive. After this you can use the `conform` script as always:

```
mix conform.new --conf myapp/config/myapp.conf --schema myapp/config/myapp.schema.exs
```

I've also provided mix tasks to handle generating your initial .conf and .schema.exs files, which includes the default options, and the documentation. The end result is an easy to maintain configuration file for your users, and ideally, a powerful tool for managing your own configuration as well.

## Custom data types

`Conform` provides ability to use custom data types in your schemas:

```elixir
[
    mappings: [
      "myapp.val1": [
        doc: "Provide some documentation for val1",
        to: "myapp.val1",
        datatype: MyModule1,
        default: 100
      ],
      "myapp.val2": [
        doc: "Provide some documentation for val2",
        to: "myapp.val2",
        datatype: [{MyModule2, [:dev, :prod, :test]}],
        default: :dev
      ]
    ],

    transforms: [
       ...
       ...
       ...
    ]
]
```

Where `MyModule1` and `MyModule2` must be modules which implement the `Conform.Type` behaviour:

```elixir
defmodule MyModule1 do
  use Conform.Type

  # Return a string to produce documentation for the given type based on it's valid values (if specified).
  # If nil is returned, the documentation specified in the schema will be used instead (if present).
  def to_doc(values) do
    "Document your custom type here"
  end

  # Converts the .conf value to this data type.
  # Should return {:ok, term} | {:error, term}
  def convert(val, _mapping) do
    {:ok, val}
  end

end
```

## Rationale

Conform is a library for Elixir applications, specifically in the release phase. Elixir already offers a convenient configuration mechanism via `config/config.exs`, but it has downsides:

- To change config settings, it requires you to recompile your app to regenerate the app.config/sys.config files used by the VM. Alternatively you can modify the sys.config file directly during deployment, using Erlang terms. Neither of these things are ops-friendly, or necessarily accessible to sysadmins who may not understand Elixir or Erlang semantics.
- You can put comments in `config/config.exs`, but once transformed to app.config/sys.config, those comments are lost, leaving sysadmins lost when trying to understand what configuration values are allowed and what they do.
- There is no config validation
- You can't offer a nice interface for configuration to your apps users via something akin to conform's translations. They have to know how to work in Elixir terms, which is pleasant enough for a dev, but not so much for someone unfamiliar with programming.

Conform is intended to fix these problems in the following way:

- It uses an init-style configuration, which should be very familiar to any sysadmin.
- It is intended to be used during the release process, once your app has been deployed.
- Conform works by taking the schema, the .conf file, and `config.exs` if it is being used, and combines them into the `sys.config` file used by the Erlang VM. However, unlike `config.exs`, you can bring the .conf into production with you, and use it for configuration instead of `sys.config`. This means that the docs provided in your schema file are available to the users configuring your application in production. The .conf is validated when it is parsed as well, so your users will get immediate feedback if they've provided invalid config settings.

I'm glad to hear from anyone using this on what problems they are having, if any, and any ideas you may have. Feel free to open issues on the tracker or come find me in `#elixir-lang` on freenode.

## License

The .conf parser in `conform_parse.peg` is licensed under Apache 2.0, per Basho. The rest of this project is licensed under the MIT license. Use as you see fit.
