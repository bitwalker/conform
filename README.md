# Conform

[![Master](https://travis-ci.org/bitwalker/conform.svg?branch=master)](https://travis-ci.org/bitwalker/conform)
[![Hex.pm Version](http://img.shields.io/hexpm/v/conform.svg?style=flat)](https://hex.pm/packages/conform)

See the full documentation [here](https://hexdocs.pm/conform).

The definition of conform is "Adapt or conform oneself to new or different conditions". As this library is used to adapt your application to its deployed environment, I think it's rather fitting. It's also a play on the word configuration, and the fact that Conform uses an init-style configuration, maintained in a `.conf` file.

# Deprecation Notice

**IMPORTANT: I am discontinuing maintenance of this project moving forward, in favor of a replacement based
on TOML, found [here](https://github.com/bitwalker/toml-elixir). It is has a formal specification and supports
much richer ways of expressing complex data (maps and lists), and supports several Elixir data types out of
the box. The `toml-elixir` library also provides a simple transformation mechnanism for extending the basic set
of datatypes with your own (including structs and records). Everything you could accomplish with Conform is doable
with `toml-elixir`, and in a cleaner, easier to maintain format. In addition, it has full support for Distillery 2.0's
config provider framework, allowing you to natively configure your Elixir releases with TOML config files**

If anyone is interested in taking over maintainership of this library, please reach out to me here via issue, or
by email, and I'll be glad to discuss the transition with you.

--------

## Features

It provides the following features:

- An easy-to-use configuration file to end-users and/or system administrators.
- Post-processing of simplified configuration options to more complex forms required by your application, 
  without pushing that complexity on the user.
- Richly-typed configuration options, such as IP addresses, URIs, etc., with the ability to define your own types.
- Automatic validation of end-user configuration against a schema
- Keep documentation of configuration options synced up automatically
- Hidden configuration options: hide advanced options from end-users, but leave them available for power users or developers
- Allow fetching information dynamically when the configuration is evaluated.
- Can be used with releases

## Rationale

Conform was designed for Elixir applications which are deployed via releases built with `exrm` or `distillery`. It was created in order
to resolve some painful issues with the configuration mechanisms provided out of the box by both Erlang and Elixir.

Elixir offers a convenient configuration mechanism via `config/config.exs`, but it has downsides:

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

The .conf parser in `conform_parse.peg` is licensed under Apache 2.0, per Basho. 

The rest of this project is licensed under the MIT license. Use as you see fit.
