# Conform

[![Build
Status](https://travis-ci.org/bitwalker/conform.svg?branch=master)](https://travis-ci.org/bitwalker/conform)

The definition of conform is "Adapt or conform oneself to new or different conditions". As this library is used to adapt your application to it's deployed environment, I think it's rather fitting. It's also a play on the word configuration, and the fact that Conform uses an init-style configuration, maintained in a `.conf` file.

Conform is a library for Elixir applications. It's original intended use is in exrm as a means of providing a simplified configuration file for deployed releases, but is flexible enough to work for any use case where you want init-style configuration translated to Elixir/Erlang terms. It is inspired directly by `basho/cuttlefish`, and in fact uses it's .conf parser. Beyond that, you can look at conform as a reduced implementation of cuttlefish in Elixir.

## Usage

You can use Conform either via it's API, which is simple and easy to pick up, or by building the escript and running that via the command line.

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

A conf file looks like the following:

```
# The location of the error log. Should be a full path, i.e. /var/log/error.log.
log.error.file = /var/log/error.log

# Just some atom.
myapp.some_val = foo

# Determine the type of thing.
# * all:  use everything
# * some: use a few things
# * none: use nothing
myapp.another_val = all
```

Short and sweet, and most importantly, easy for sysadmins and users to understand and modify. But we don't want to maintain a bunch of different configuration files, we want one source of truth, or at the most two: default configuration via `config.exs`, and configuration supplied at release-time via `myapp.conf`. But how do we avoid maintaining this third config file? Enter schema files:

```elixir
[

  mappings: [
    "log.error.file": [
      doc:      "The location of the error log. Should be a full path, i.e. /var/log/error.log.",
      to:       "log.error_file",
      datatype: :binary,
      default:  "/var/log/error.log"
    ],
    "myapp.some_val": [
      doc:      "Just some atom.",
      to:       "myapp.some_val",
      datatype: :atom,
      default:  :foo
    ],
    "myapp.another_val": [
      doc: """
        Determine the type of thing.
        * all:  use everything
        * some: use a few things
        * none: use nothing
        """,
      to:       "myapp.another_val",
      datatype: [enum: [:all, :some, :none]],
      default:  :all,
    ]
  ],

  translations: [
    "myapp.another_val": fn val ->
      case val do
        :all  -> {:on, [debug: true, tracing: true]}
        :some -> {:on, [debug: true]}
        :none -> {:off, []}
        _     -> {:off, []}
      end
    end
  ]

]
```

This looks pretty much like `config.exs` on steroids. Schemas consist of two types of things, mappings, and translations. Mappings are defined by four properties:

- `:doc`, documentation on what this setting is, and how to use it
- `:to`, if you want friendly names for not so friendly app settings, `:to` tells conform what setting this mapping applies to in the generated `.config`
- `:datatype`, the datatype of the value, currently supports binary, charlist, atom, integer, float, ip, and enum. More to come.
- `:default`, optional, the value to use if one is not supplied for this setting

After a setting is parsed according to it's mapping, if a translation exists for that setting, the parsed value is passed to the translation function to get the final value for the `.config` file. As you can see above, we expose simplified settings for `myapp.another_val`, but translate them to their more useful format for our code.

The result configuration file generated with the above combined conf and schema files is the following:

```erlang
[{myapp, [
  {another_val, {on, [{debug, true}, {tracing, true}]}},
  {some_val, foo}]},
 {log, [
  {error_file, <<"/var/log/error.log">>}]}].
```

As you can see, if your sysadmins had to work with the above, versus the .conf, it would be quite prone to mistakes, and much harder to understand, particularly with the lack of comments or documentation.

The real beauty of this though is that we can generate a default `myapp.conf` file based on the schema, which includes the default options, and the documentation. You could generate your `config.exs` file from it as well, though I haven't wired that up just yet. The end result is an easy to maintain configuration file for your users, and ideally, a powerful tool for managing your own configuration as well.

## Rationale 

Conform is a library for Elixir applications, specifically in the release phase. Elixir already offers a convenient configuration mechanism via `config/config.exs`, but it has downsides:

- Configuration is converted to an app.config or sys.config at compile time, which is not useful for applications which require environment-specific configuration, such as app secrets, connection strings, etc.
- Modifying the configuration requires you to recompile your app to regenerate the app.config/sys.config files used by the VM. Alternatively you can modify the sys.config file directly during deployment, using Erlang terms. Neither of these things are ops-friendly, or necessarily accessible to sysadmins who may not understand Elixir or Erlang semantics.
- You can put comments in `config/config.exs`, but once transformed to app.config/sys.config, those comments are lost, leaving sysadmins lost when trying to understand what configuration values are allowed and what they do.

Conform is intended to fix these problems in the following way:

- It uses an init-style configuration, which should be very familiar to any sysadmin.
- It is intended to be used during the release process, once your app has been deployed.
- It makes use of the configuration generated by `config/config.exs` as the default configuration, but gives sysadmins an easy way to tune and configure your app in production.
- Conform works by taking `config/schema.exs`, combining the schema with values provided in `config/config.exs`, and generating a `config/myapp.conf` file which can then be modified prior to app startup. The `config/myapp.conf` file is then transformed into the `sys.config` file used by the VM for application configuration. Any documentation provided in `schema.exs` is also displayed in the `myapp.conf` file, so that individuals maintaing the config are able to easily understand the constraints.
- No compilation step required.

This project is just getting started, but stay tuned for more. This will be rolled in to exrm in the near future, as soon as this is ready for production.

## License

The .conf parser in `conf_parse.peg` is licensed under Apache 2.0, per Basho. The rest of this project is licensed under the MIT license. Use as you see fit.

