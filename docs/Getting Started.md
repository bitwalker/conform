# Getting Started

## Installation

Add `conform` to your dependency list in mix.exs:

```elixir
defp deps do
 [{:conform, "~> 2.2"}, ...]
end
```

Run `mix do deps.get, compile` and you are ready to go!

## First Steps

The first thing you'll want to do is generate a `.schema.exs` file from your existing `config.exs` file. You can do this by running
`mix conform.new`. Once you've finished reading the documentation here, you'll want to go edit that file according to how you want
users to configure your application. Once you've finished editing the schema, you can generate an initial `.conf` file with
`mix conform.configure`. You can then test the evaluation of the `.conf` against your current schema with `mix conform.effective`.

**IMPORTANT**: You really really should read the full docs before you dive in, it will make your life a lot easier!

## General Usage

### Command Line

Conform provides an escript, `priv/bin/conform` (or you can compile it manually with `MIX_ENV=prod mix escript.build` a checkout from git),
which you can drop anywhere and use.

Usage instructions are provided with `conform --help` wk

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
  --code-path <path>:   Adds the given path to the current code path, accepts wildcards.
  -h | --help:          Prints this help
```

### Mix Tasks

Conform provides some Mix tasks for use within your project:

- `mix conform.new` - Generates a schema from your current project configuration
- `mix conform.configure` - Generates a default `.conf` from your schema file and current project configuration
- `mix conform.effective` - View the effective configuration for the current project and environment.
- `mix conform.archive` - Creates an `<app>.schema.ez` archive next to the application's schema, this archive contains
  any dependencies which the schema requires in order to execute.

There are additional options for some of these tasks, use `mix help <task>` to view their documentation.

## Files. Files Everywhere.

Conform introduces two new configuration files, a configuration schema (`<app>.schema.exs`), and a configuration file
(`<app>.<env>.conf`). This is in addition to the `config.exs` file you are probably already familiar with, and then there
is the `sys.config` file used by releases. This has the appearance of madness I know, but all of these pieces have their place,
and hopefully you'll see why this makes your life easier rather than the other way around. Let me try telling this in terms of a story:

In the beginning, there was `sys.config`, and it was good. You could easily configure your application in one
file, and tell the VM to use that file when booting up. It lacked runtime dynamism though (i.e. environment variables), for which you needed to use other VM flags to provide such configuration values. Even then, one still couldn't inject configuration via the environment as any type
other than a string. To this day, `sys.config` is still the primary means of configuring the Erlang VM.

Along came Elixir, a fresh take on the venerable Erlang. Along with it, came `config.exs`, as the solution to all the ills of `sys.config`.
Or so it seemed. It solved runtime dynamism, and extracting typed configuration from the environment, by allowing you to execute arbitrary
Elixir code in the config file when it was evaluated. A miracle! However it has one flaw, and it unfortunately undermines a lot of the power
that `config.exs` provides: it is intrinsically tied to the Mix project structure, and thus cannot be used with releases, which require `sys.config`. The solution is to evaluate `config.exs` and convert the resulting configuration to `sys.config` - but now you've removed the ability
to do any runtime configuration by fetching variables from the environment. Ultimately this leaves us where we started.

It is at this point that various workarounds developed, for example, the convention of configuring via `{:system, "VAR"}` tuples. Unfortunately, this convention is neither universal, nor consistent - you are ultimately at the mercy of your dependencies in this regard.

At the same time, both `exrm` and `distillery` provided a way to "cheat" the `sys.config` by doing textual replacements of `$SOME_VAR`-style
variables with their corresponding values from the environment. This works, but provides no way to do any validation or post-processing.

Another big problem has been completely ignored up until this point as well: what about when you need end users to configure the application, or even sys admins or devops teams who have no expertise in Elixir/Erlang whatsoever. In addition, how do you expose some configuration,
but not all configuration?

It just so happens that Basho had developed a tool for Erlang applications called `cuttlefish`. Conform was born as an Elixir counterpart
to that. Both tools seek to solve all of the above-mentioned problems using the two new files mentioned in the beginning, the schema, and the end-user configuration file, the .conf.

- The issue of runtime dynamism is solved by evaluating the configuration at runtime, prior to the application start
- The issue of validation and post-processing is solved via the schema
- End-user configuration is all done via the `.conf`. Defaults can be set via the traditional `config.exs` or `sys.config` files
- Configuration options can be hidden.
- Configuration options can be documented in the schema, and this flows through to the end-user config file for easier use.

The general idea is that `config.exs` is used to set the bare-minimum defaults of the system, the `.schema.exs` file defines the
options which users will configure in the `.conf`, what their types are, their documentation, whether they are hidden, and how they will be transformed to the configuration ultimately consumed by the system. Conform runs prior to booting the application, merging the result of evaluating the `.conf` (using the schema to guide this evaluation), over the top of the `sys.config` file. This produces a *new* `sys.config`, which
is ultimately used by the VM during boot.

## End-to-end Example

Let's try to make this more concrete by taking a look at an example from `.conf` through to the final `sys.config`:

### .conf

Here is what our example `app.conf` file looks like:

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

Our example tries to make use of a few different features, so we've got some rather odd things we're configuring, but let's assume it all makes perfect sense.

Some things to remember: 

- You do not need to quote strings, unless they need to contain whitespace literals, e.g. `\n`, or double-quotes. We explicitly quote some things anyway just for kicks, but it's not necessary.
- You form lists of things with `, ` between elements.
- You form nested lists with explicit brackets, e.g. `[1, 2], [3, 4]`
- Referencing Elixir modules currently requires the explicit `Elixir.` prefix.

So all in all, it's short and sweet, and most importantly, easy for sysadmins and users to understand and modify. 

### .schema.exs

The real power though is when you dig into the schema file. It allows you to define documentation, mappings between friendly setting names and specific application settings in the underlying sys.config, define validation of values via datatype specifications, provide default values, and transform simplified values from the .conf into something more meaningful to your application using translation functions.

A schema is basically a single data structure. A keyword list, containing the following top-level properties, `extends`, `import`, `mappings`, and `transforms`. Before we dive in, here's the schema which we'll use with our `.conf` from before:

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
      default: "/var/log/console.log",
      env_var: "LAGER_INFO_FILE"
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

#### Mappings

Mappings are defined by four key properties (there are more, just see the `Conform.Schema.Mapping` module docs):

- `:doc`, documentation on what this setting is, and how to use it
- `:to`, if you want friendly names for not so friendly app settings, `:to` tells conform what setting this mapping applies to in the generated `.config`
- `:datatype`, the datatype of the value, currently supports binary, charlist, atom, integer, float, ip (a tuple of strings `{ip, port}`), enum, and lists of one of those types.
- `:default`, optional, the value to use if one is not supplied for this setting. Should be the same form as the datatype for the setting. So for example, if you have a setting, `myapp.foo`, with a datatype of `[enum: [:info, :warn, :error]]`, then your default value should be one of those three atoms.
- `:env_var`, optional, the environment variable to use for sourcing the input value if the option is not set explicitly in the `.conf`. If this environment variable is not set, then `:default` will be used.

#### Transforms

After all settings have been mapped, each of the transforms is executed with the PID of the ETS table holding the config. You will need to use the `Conform.Conf` module API to query the configuration state using this PID. The value returned from the transform is then paired with the key the transformed is defined against and used in the final configuration.

### Putting it together

The following is the output configuration from Conform using the `.conf` and `.schema.exs` files shown above:

*NOTE*: Assume that `LAGER_INFO_FILE=/var/log/info.log` is set in the environment for purposes of this demonstration.

```erlang
[lager: [handlers: [
             lager_console_backend: :info,
             lager_file_backend: [file: "/var/log/info.log", level: :info],
             lager_file_backend: [file: "/var/log/error.log",  level: :error]
           ]],
 my_app: [another_val: {:on, [{:debug, true}, {:tracing, true}]},
          complex_list: [first: [age: 20, username: "username1"],
                        second: [age: 40, username: "username2"]],
          db: [hosts: [{"127.0.0.1", "8000"}, {"127.0.0.2", "8001"}]],
          some_val: :foo]]
```

As you can see, if your sysadmins had to work with the above, versus the `.conf`, it would be quite prone to mistakes, and much harder to understand, particularly with the lack of comments or documentation.





