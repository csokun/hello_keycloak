defmodule Mix.Tasks.Heroicons do
  use Mix.Task

  require Logger

  def run([hero_vsn]) when is_binary(hero_vsn) do
    filename = "v#{hero_vsn}.tar.gz"
    url = "https://github.com/tailwindlabs/heroicons/archive/refs/tags/#{filename}"

    dest_dir = Path.join([File.cwd!(), "assets", "vendor", "heroicons"])
    File.mkdir_p!(dest_dir)
    binary = fetch_body!(url)

    dest_file = Path.join([dest_dir, filename])
    File.write!(dest_file, binary, [:binary])

    extract(dest_file, hero_vsn)

    IO.puts("Heroicons #{hero_vsn} downloaded and extracted to #{dest_dir}")
  end

  def run(_) do
    IO.puts("Usage: mix fetch_heroicons <version>")
  end

  defp extract(file, hero_vsn) do
    optimized_path = "heroicons-#{hero_vsn}/optimized"
    Logger.info("Extracting #{file}")

    with {:ok, tar_files} <- :erl_tar.table(file, [:compressed]) do
      optimized_files =
        Enum.filter(tar_files, fn item ->
          List.to_string(item) |> String.starts_with?(optimized_path)
        end)

      :erl_tar.extract(file, [:compressed, {:files, optimized_files}])
      File.cp_r!("heroicons-#{hero_vsn}", "assets/vendor/heroicons")
      File.rm_rf!("heroicons-#{hero_vsn}")
      File.rm!(file)
    else
      {:error, reason} ->
        raise """
        Couldn't extract #{file}: #{inspect(reason)}
        """
    end
  end

  defp fetch_body!(url) do
    scheme = URI.parse(url).scheme
    url = String.to_charlist(url)
    Logger.debug("Downloading tailwind from #{url}")

    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    if proxy = proxy_for_scheme(scheme) do
      %{host: host, port: port} = URI.parse(proxy)
      Logger.debug("Using #{String.upcase(scheme)}_PROXY: #{proxy}")
      set_option = if "https" == scheme, do: :https_proxy, else: :proxy
      :httpc.set_options([{set_option, {{String.to_charlist(host), port}, []}}])
    end

    # https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/inets
    cacertfile = cacertfile() |> String.to_charlist()

    http_options =
      [
        ssl: [
          verify: :verify_peer,
          cacertfile: cacertfile,
          depth: 2,
          customize_hostname_check: [
            match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
          ],
          versions: protocol_versions()
        ]
      ]
      |> maybe_add_proxy_auth(scheme)

    options = [body_format: :binary]

    case :httpc.request(:get, {url, []}, http_options, options) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        body

      other ->
        raise """
         Couldn't fetch #{url}: #{inspect(other)}
        """
    end
  end

  defp proxy_for_scheme("http") do
    System.get_env("HTTP_PROXY") || System.get_env("http_proxy")
  end

  defp proxy_for_scheme("https") do
    System.get_env("HTTPS_PROXY") || System.get_env("https_proxy")
  end

  defp maybe_add_proxy_auth(http_options, scheme) do
    case proxy_auth(scheme) do
      nil -> http_options
      auth -> [{:proxy_auth, auth} | http_options]
    end
  end

  defp proxy_auth(scheme) do
    with proxy when is_binary(proxy) <- proxy_for_scheme(scheme),
         %{userinfo: userinfo} when is_binary(userinfo) <- URI.parse(proxy),
         [username, password] <- String.split(userinfo, ":") do
      {String.to_charlist(username), String.to_charlist(password)}
    else
      _ -> nil
    end
  end

  defp cacertfile() do
    Application.get_env(:tailwind, :cacerts_path) || CAStore.file_path()
  end

  defp protocol_versions do
    if otp_version() < 25, do: [:"tlsv1.2"], else: [:"tlsv1.2", :"tlsv1.3"]
  end

  defp otp_version do
    :erlang.system_info(:otp_release) |> List.to_integer()
  end
end
