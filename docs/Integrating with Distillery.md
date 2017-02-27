## Integrating with Distillery

All you need to use Conform with Distillery is to set the plugin in your release config:

```elixir
release :test do
  set version: current_version(:test)

  plugin Conform.ReleasePlugin
end
```

This will do everything necessary to ensure that the `.schema.exs`, `.conf`, and any dependencies are included
in the release, and will automatically execute Conform prior to booting the release.
