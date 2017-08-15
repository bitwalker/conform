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

  # Used to check compatibility with certain features or changes
  defmacrop if_distillery(op, version, do: block, else: else_block)
    when op in [:lt, :gt, :eq] and is_binary(version) do
      quote location: :keep do
        distillery_vsn =
          :distillery
          |> Application.spec
          |> Keyword.get(:vsn)
          |> to_string

        case Version.parse(distillery_vsn) do
          :error ->
            case String.split(distillery_vsn, ".") do
              [major, minor | _] ->
                if Version.compare(Version.parse!("#{major}.#{minor}.0"), Version.parse!(unquote(version))) == unquote(op) do
                  unquote(block)
                else
                  unquote(else_block)
                end
              _ ->
                unquote(block)
            end
          {:ok, vsn} ->
            if Version.compare(vsn, unquote(version)) == unquote(op) do
              unquote(block)
            else
              unquote(else_block)
            end
        end
      end
  end

  def before_assembly(%{profile: %{overlays: overlays} = profile} = release) do
    include_pre_start? =
      if_distillery :lt, "1.2.0", do: true, else: false
    pre_or_post_configure =
      if_distillery :lt, "1.5.0", do: "pre_configure", else: "post_configure"

    post_configure_src = Path.join(["#{:code.priv_dir(:conform)}", "bin", "#{pre_or_post_configure}.sh"])
    pre_upgrade_src = Path.join(["#{:code.priv_dir(:conform)}", "bin", "pre_upgrade.sh"])
    post_upgrade_src = Path.join(["#{:code.priv_dir(:conform)}", "bin", "post_upgrade.sh"])
    debug "loading schema"

    conf_src   = get_conf_path(release)
    schema_src = get_schema_path(release)

    # Define overlays
    conform_overlays =
      if include_pre_start? do
        [{:copy, post_configure_src, "releases/<%= release_version %>/hooks/pre_start.d/00_conform_pre_configure.sh"},
         {:copy, post_configure_src, "releases/<%= release_version %>/hooks/#{pre_or_post_configure}.d/00_conform_#{pre_or_post_configure}.sh"},
         {:copy, pre_upgrade_src, "releases/<%= release_version %>/hooks/pre_upgrade.d/00_conform_pre_upgrade.sh"},
         {:copy, post_upgrade_src, "releases/<%= release_version %>/hooks/post_upgrade.d/00_conform_post_upgrade.sh"},
         {:copy, schema_src, "releases/<%= release_version %>/<%= release_name %>.schema.exs"}]
      else
        [{:copy, post_configure_src, "releases/<%= release_version %>/hooks/#{pre_or_post_configure}.d/00_conform_#{pre_or_post_configure}.sh"},
         {:copy, pre_upgrade_src, "releases/<%= release_version %>/hooks/pre_upgrade.d/00_conform_pre_upgrade.sh"},
         {:copy, post_upgrade_src, "releases/<%= release_version %>/hooks/post_upgrade.d/00_conform_post_upgrade.sh"},
         {:copy, schema_src, "releases/<%= release_version %>/<%= release_name %>.schema.exs"}]
      end

    if File.exists?(schema_src) do
      conform_overlays =
        conform_overlays
        |> add_archive(release, schema_src)
        |> add_conf(release, conf_src)
        |> add_escript(release)
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

  defp add_archive(conform_overlays, release, schema_src) do
    # generate archive
    result = Mix.Tasks.Conform.Archive.run(["#{schema_src}"])
    # add archive to the overlays
    case result do
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
          "releases/<%= release_version %>/<%= release_name %>.schema.ez"} | conform_overlays]
    end
  end

  defp add_conf(conform_overlays, _release, conf_src) do
    case File.exists?(conf_src) do
      true ->
      [{:copy,
          conf_src,
          "releases/<%= release_version %>/<%= release_name %>.conf"} | conform_overlays]
      false -> conform_overlays
    end
  end

  defp add_escript(conform_overlays, _release) do
    debug "generating escript"
    escript_path = Path.join(["#{:code.priv_dir(:conform)}", "bin", "conform"])
    [{:copy, escript_path, "releases/<%= release_version %>/conform"} | conform_overlays]
  end

  defp generate_umbrella_schema(release) do
    schemas = Enum.reduce(umbrella_apps_paths(), [], fn({name, path}, acc) ->
      schema =
        path
        |> Path.join("config/#{name}.schema.exs")
        |> Conform.Schema.load

      case schema do
        {:ok, schema} ->
          debug "merging schema #{name}"
          [schema | acc]
        {:error, msg} ->
          debug msg
          acc
      end
    end)

    {:ok, tmp_dir} = Mix.Releases.Utils.insecure_mkdir_temp
    schema = Conform.Schema.coalesce(schemas)

    tmp_schema_src = Path.join(tmp_dir, "#{release.name}.schema.exs")
    Conform.Schema.write(schema, tmp_schema_src)

    tmp_schema_src
  end

  ## Concatenantes all conf files into a single umbrella conf file
  defp generate_umbrella_conf(release) do
    conf_files = Enum.reduce(umbrella_apps_paths(), [], fn({name, path}, acc) ->
      conf_path = case File.exists?(Path.join(path, "config/#{name}.#{Mix.env}.conf")) do
                    true  -> Path.join(path, "config/#{name}.#{Mix.env}.conf")
                    false -> Path.join(path, "config/#{name}.conf")
                  end
      case File.read(conf_path) do
        {:ok, data} ->
          debug "merging config #{name}"
          [data | acc]
        {:error, _} ->
          debug "no conf found, skipping #{conf_path}"
          acc
      end
    end)

    {:ok, tmp_dir} = Mix.Releases.Utils.insecure_mkdir_temp
    conf = Enum.join(conf_files, "\n")

    tmp_conf_src = Path.join(tmp_dir, "#{release.name}.conf")
    File.write!(tmp_conf_src, conf)
    tmp_conf_src
  end

  ## Backport from Elixir 1.4.0 `Mix.Project.apps_paths/1`
  defp umbrella_apps_paths do
    config = Mix.Project.config
    if apps_path = config[:apps_path] do
      apps_path
      |> Path.join("*/mix.exs")
      |> Path.wildcard()
      |> Enum.map(&Path.dirname/1)
      |> extract_umbrella
      |> filter_umbrella(config[:apps])
      |> Map.new
    end
  end

  defp umbrella_child_names do
    umbrella_apps_paths() |> Map.keys
  end

  ## Umbrella apps don't have a name in their mix project.
  ## Instead we check to see if the release is an umbrella release, and that the
  ## name of the release *is not* one of the apps in the umbrella.
  defp releasing_umbrella?(name) do
    case Mix.Project.umbrella? do
      true  -> !Enum.member?(umbrella_child_names(), name)
      false -> false
    end
  end

  defp extract_umbrella(paths) do
    for path <- paths do
      app = path |> Path.basename |> String.downcase |> String.to_atom
      {app, path}
    end
  end

  defp filter_umbrella(pairs, nil), do: pairs
  defp filter_umbrella(pairs, apps) when is_list(apps) do
    for {app, _} = pair <- pairs, app in apps, do: pair
  end

  defp get_conf_path(release) do
    case releasing_umbrella?(release.name) do
      true  -> generate_umbrella_conf(release)
      false ->
        src_dir = Conform.Utils.src_conf_dir(release.name)
        case File.exists?(Path.join(src_dir, "#{release.name}.#{Mix.env}.conf")) do
          true ->
            Path.join(src_dir, "#{release.name}.#{Mix.env}.conf")
          false ->
            Path.join(src_dir, "#{release.name}.conf")
        end
    end
  end

  defp get_schema_path(release) do
    case releasing_umbrella?(release.name) do
      true  -> generate_umbrella_schema(release)
      false -> Conform.Schema.schema_path(release.name)
    end
  end
end
