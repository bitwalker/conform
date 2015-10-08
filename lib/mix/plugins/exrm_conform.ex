if Code.ensure_loaded?(ReleaseManager.Plugin) do
  defmodule ReleaseManager.Plugin.Conform do
    @name "conform"
    @shortdoc "Generates a .conf for your release"
    @moduledoc """
    Generates a .conf for your release

    This plugin ensures that your application has a .schema.exs
    and .conf file for setting up configuration via the `conform`
    library. This .conf file then offers a simplified interface
    for sysadmins and other deployment staff for easily configuring
    your release in production.
    """

    use   ReleaseManager.Plugin
    alias ReleaseManager.Config
    alias ReleaseManager.Utils

    def before_release(%Config{name: app, version: version}) do
      relx_conf_path = Utils.rel_file_dest_path("relx.config")
      conf_src       = Path.join([File.cwd!, "config", "#{app}.conf"])

      debug "Conform: Loading schema..."
      schema_src = Conform.Schema.schema_path(app)
      if File.exists?(schema_src) do
        # Define overlays for relx.config
        overlays = [{:copy, '#{schema_src}', 'releases/#{version}/#{app}.schema.exs'}]
        # generate archive
        result = Mix.Task.run("conform.archive", ["#{schema_src}"])
        # add archive to the overlays
        overlays = case result do
          {_, _, []} ->
            {:ok, cwd} = File.cwd
            arch = "#{cwd}/rel/releases/#{version}/#{app}.schema.ez"
            case File.exists?(arch) do
              true  -> File.rm(arch)
              false -> :ok
            end
            overlays
          {_, zip_path, _} ->
            [{:copy, '#{zip_path}', 'releases/#{version}/#{app}.schema.ez'}|overlays]
        end

        overlays = case File.exists?(conf_src) do
          true ->
            [{:copy, '#{conf_src}', 'releases/#{version}/#{app}.conf'}|overlays]
          false ->
            overlays
        end

        # Generate escript for release
        debug "Conform: Generating escript.."
        escript_path = Mix.Task.run("conform.release")
        overlays = [{:copy, '#{escript_path}', 'releases/#{version}/conform'}|overlays]

        # Add .conf, .schema.exs, and escript to relx.config as overlays
        debug "Conform: Adding overlays to relx.config..."
        relx_config = relx_conf_path |> Utils.read_terms
        updated = Utils.merge(relx_config, [overlay: overlays])

        # Persist relx.config
        Utils.write_terms(relx_conf_path, updated)

        debug "Conform: Done!"
      end
    end

    def after_release(_), do: nil
    def after_package(_), do: nil
    def after_cleanup(_), do: nil

  end
end
