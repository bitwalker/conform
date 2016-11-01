defmodule Conform.ReleasePlugin do
  Module.register_attribute __MODULE__, :name, accumulate: false, persist: true
  Module.register_attribute __MODULE__, :moduledoc, accumulate: false, persist: true
  Module.register_attribute __MODULE__, :shortdoc, accumulate: false, persist: true
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
  def before_assembly(%{profile: %{overlays: overlays} = profile} = release) do
    conf_src = Path.join([Conform.Utils.src_conf_dir(release.name), "#{release.name}.conf"])
    pre_start_src = Path.join(["#{:code.priv_dir(:conform)}", "bin", "pre_start.sh"])
    debug "loading schema"
    schema_src = Conform.Schema.schema_path(release.name)
    if File.exists?(schema_src) do
      # Define overlays
      conform_overlays = [
        {:copy, pre_start_src, "releases/<%= release_version %>/hooks/pre_start.d/conform_pre_start.sh"},
        {:copy, schema_src, "releases/<%= release_version %>/<%= release_name %>.schema.exs"}]
      # generate archive
      result = Mix.Tasks.Conform.Archive.run(["#{schema_src}"])
      # add archive to the overlays
      conform_overlays = case result do
        {_, _, []} ->
          {:ok, cwd} = File.cwd
          arch = "#{cwd}/rel/releases/#{release.version}/#{release.name}.schema.ez"
          case File.exists?(arch) do
            true  -> File.rm(arch)
            false -> :ok
          end
          conform_overlays
        {_, zip_path, _} ->
          [{:copy,
            "#{zip_path}",
            "releases/<%= release_version %>/<%= release_name %>.schema.ez"}|conform_overlays]
      end

      conform_overlays = case File.exists?(conf_src) do
        true ->
        [{:copy,
            conf_src,
            "releases/<%= release_version %>/<%= release_name %>.conf"}|conform_overlays]
        false ->
          conform_overlays
      end

      # Generate escript for release
      debug "generating escript"
      escript_path = Path.join(["#{:code.priv_dir(:conform)}", "bin", "conform"])
      conform_overlays = [{:copy, escript_path, "releases/<%= release_version %>/conform"}|conform_overlays]

      # Add .conf, .schema.exs, and escript to relx.config as overlays
      debug "done!"
      %{release | :profile => %{profile | :overlays => overlays ++ conform_overlays}}
    else
      debug "no schema found, skipping"
      release
    end
  end

  def after_assembly(_release), do: nil
  def before_package(_release), do: nil
  def after_package(_release), do: nil
  def after_cleanup(_args), do: nil

  defp debug(message), do: apply(Mix.Releases.Logger, :debug, ["conform: " <> message])
end
