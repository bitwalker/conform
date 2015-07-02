# Conform

[![Build
Status](https://travis-ci.org/bitwalker/conform.svg?branch=master)](https://travis-ci.org/bitwalker/conform)

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
myapp.db.hosts = 127.0.0.1:8000, 127.0.0.2:8001

# Just some atom.
myapp.some_val = foo

# Determine the type of thing.
# * all:  use everything
# * some: use a few things
# * none: use nothing
# Allowed values: all, some, none
myapp.another_val = all

# complex data types with wildcard support
complex_list.first.username = "username1"
complex_list.first.age = 20
complex_list.second.username = "username2"
complex_list.second.age = 40
```

Short and sweet, and most importantly, easy for sysadmins and users to understand and modify. The real power of conform though is when you dig into the schema file. It allows you to define documentation, mappings between friendly setting names and specific application settings in the underlying sys.config, define validation of values via datatype specifications, provide default values, and transform simplified values from the .conf into something more meaningful to your application using translation functions. 

A schema is basically a single data structure. A keyword list, containing two top-level properties, `mappings`, and `translations`. Before we dive in, here's the schema for the .conf file above:

```elixir
[
  mappings: [
    "lager.handlers.console.level": [
      doc: """
      Choose the logging level for the console backend.
      """,
      to: "lager.handlers",
      datatype: [enum: [:info, :error]],
      default: :info
    ],
    "lager.handlers.file.error": [
      doc: """
      Specify the path to the error log for the file backend
      """,
      to: "lager.handlers",
      datatype: :binary,
      default: "/var/log/error.log"
    ],
    "lager.handlers.file.info": [
      doc: """
      Specify the path to the console log for the file backend
      """,
      to: "lager.handlers",
      datatype: :binary,
      default: "/var/log/console.log"
    ],
    "myapp.db.hosts": [
      doc: "Remote database hosts",
      to: "myapp.db.hosts",
      datatype: [list: :ip],
      default: [{"127.0.0.1", "8001"}]
    ],
    "myapp.some_val": [
      doc:      "Just some atom.",
      to:       "myapp.some_val",
      datatype: :atom,
      default:  :foo
    ],
    "my_app.complex_list.*": [
      to: "my_app.complex_list",
      datatype: [:complex],
      default: []
    ],
    "my_app.complex_list.*.type": [
      to: "my_app.complex_list",
      datatype: :atom,
      default:  :undefined
    ],
    "my_app.complex_list.*.age": [
      to: "my_app.complex_list",
      datatype: :integer,
      default: 30
    ]
  ],

  translations: [
    "myapp.another_val": fn val ->
      case _mapping, val do
        :all  -> {:on, [debug: true, tracing: true]}
        :some -> {:on, [debug: true]}
        :none -> {:off, []}
        _     -> {:off, []}
      end
    end,
    "lager.handlers.console.level": fn
      _mapping, level, nil when level in [:info, :error] ->
          [lager_console_backend: level]
      _mapping, level, acc when level in [:info, :error] ->
          acc ++ [lager_console_backend: level]
      _, level, _ ->
        IO.puts("Unsupported console logging level: #{level}")
        exit(1)
    end,
    "lager.handlers.file.error": fn 
      _, path, nil ->
        [lager_file_backend: [file: path, level: :error]]
      _, path, acc ->
        acc ++ [lager_file_backend: [file: path, level: :error]]
    end,
    "lager.handlers.file.info": fn
      _, path, nil ->
        [lager_file_backend: [file: path, level: :info]]
      _, path, acc ->
        acc ++ [lager_file_backend: [file: path, level: :info]]
    end,
    "my_app.complex_list.*": fn _, {key, value_map}, acc ->
    [[name: key,
      username: value_map[:username],
      age:  value_map[:age]
     ] | acc]
    end
  ]
]
```

This looks pretty daunting, but I've provided mix tasks to help you generate the schema from your existing `config.exs` file. Once you've gotten the schema tightened up though, you'll start to understand why it's worth a little extra effort up front. So schemas consist of two types of things: mappings and translations. Mappings are defined by four properties:

- `:doc`, documentation on what this setting is, and how to use it
- `:to`, if you want friendly names for not so friendly app settings, `:to` tells conform what setting this mapping applies to in the generated `.config`
- `:datatype`, the datatype of the value, currently supports binary, charlist, atom, integer, float, ip (a tuple of strings `{ip, port}`), enum, and lists of one of those types. I currently am planning on supporting user-defined types, but that work has not yet been completed.
- `:default`, optional, the value to use if one is not supplied for this setting. Should be the same form as the datatype for the setting. So for example, if you have a setting, `myapp.foo`, with a datatype of `[enum: [:info, :warn, :error]]`, then your default value should be one of those three atoms.

After a mapping is parsed according to its schema definition, if a translation function with an arity of 2 or 3 exists for that mapping, the function is called with the following parameters: `mapping` and `value`, and optionally `accumulator`, if you provide a translation function with an arity of 3. The `mapping` parameter is basically what you would expect -- the mapping for the setting associated with the currently executing translation. The `value` is of course the value you are translating. `accumulator` is a bit different, but works the way it sounds. If you provide multiple mappings with the same `to` path, then translations for those mappings will receive an accumulated value for that config setting. In the example above, you can see I defined multiple mappings that all had different names, but pointed to the same underlying field. Each translation handles both the case where the accumulator is nil, or already contains a list of values. Let's take a look at what the final output of the combined .conf and schema files will look like.

```erlang
[{lager, [
  {handlers, [
    {lager_console_backend, info},
    {lager_file_backend, [{file, "var/log/error.log"},    {level, error}]}, 
    {lager_file_backend, [{file, "/var/log/console.log"}, {level, info}]}
  ]}]},
 {myapp, [
  {another_val, {on, [{debug, true}, {tracing, true}]}},
  {some_val, foo},
  {db, [{hosts, [{"127.0.0.1", "8001"}]}]},
  [complex_list: [first: %{age: 20, username: "username1"},
                  second: %{age: 40, username: "username2"}]]
]}].
```

As you can see, if your sysadmins had to work with the above, versus the .conf, it would be quite prone to mistakes, and much harder to understand, particularly with the lack of comments or documentation. If you need to import any applications from the `your_app/deps`, you can update your `you_app.schema.exs` with the `import`:

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

	translations: [
		...
		...
		...
	]
]
```

The `my_app_dep1` and `my_app_dep2` will be loaded from the `your_app/deps` and you can use any public API from these applications in the translations.

I've provided mix tasks to handle generating your initial .conf and .schema.exs files, which includes the default options, and the documentation. The end result is an easy to maintain configuration file for your users, and ideally, a powerful tool for managing your own configuration as well.

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

The .conf parser in `conf_parse.peg` is licensed under Apache 2.0, per Basho. The rest of this project is licensed under the MIT license. Use as you see fit.

