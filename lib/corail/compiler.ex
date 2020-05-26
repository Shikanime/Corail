defmodule Corail.Compiler do
  @moduledoc false

  @config_schema [
    cmake: [
      type: :string,
      default: "cmake"
    ],
    project: [
      type: :binary
    ],
    build_mode: [
      type: {:one_of, [:debug, :release]}
    ],
    skip_compilation: [
      type: :boolean,
      default: false
    ],
    generator: [
      type: :string
    ],
    generator_dir: [
      type: :string
    ],
    cmd_opts: [
      type: :keyword_list
    ]
  ]

  @doc false
  def compile_cmake(module, otp_app, opts) do
    config =
      Application.get_env(otp_app, module, [])
      |> Keyword.merge(opts)
      |> NimbleOptions.validate!(@config_schema)

    project = Keyword.get(config, :project, otp_app)
    project_path = "native/#{project}"
    project_absolute_path = Path.expand(project_path, File.cwd!())

    load_path = "native/lib#{project}"
    resources = external_resources(project_path)

    if Keyword.fetch!(config, :skip_compilation) do
      {:ok, {load_path, resources}}
    else
      cmd = Keyword.fetch!(config, :cmd)

      cmd_opts =
        config
        |> Keyword.get(:cmd_opts, [])
        |> Keyword.merge(
          cd: project_absolute_path,
          stderr_to_stdout: true,
          into: IO.stream(:stdio, :line)
        )

      generator = Keyword.fetch!(opts, :generator)

      generator_dir =
        Keyword.get_lazy(config, :generator_dir, fn ->
          Application.app_dir(otp_app, project_path)
        end)

      generate_opts = [
        generator: generator,
        generator_dir: generator_dir,
        cmd_opts: cmd_opts
      ]

      build_mode = Keyword.fetch!(config, :build_mode) |> translate_build_mode()

      build_opts = [
        build_mode: build_mode,
        cmd_opts: cmd_opts
      ]

      Mix.shell().info([
        "Compilling project ",
        project,
        " with ",
        generator,
        " in ",
        build_mode,
        " (",
        project_path,
        ")"
      ])

      with :ok <- generate_cmake(cmd, generate_opts),
           :ok <- build_cmake(cmd, build_opts),
           do: {:ok, {load_path, resources}}
    end
  end

  defp external_resources(path) do
    "#{path}/**/*"
    |> Path.wildcard()
    |> Enum.reject(&String.starts_with?(&1, "#{path}/build/"))
  end

  defp translate_build_mode(nil) do
    if Mix.env() in [:prod, :bench],
      do: :release,
      else: :debug
  end

  defp translate_build_mode(build_mode) do
    build_mode
  end

  @priv_dir "priv/native"

  defp generate_cmake(cmd, opts) do
    generator = Keyword.fetch!(opts, :generator)
    generator_dir = Keyword.fetch!(opts, :generator_dir)

    args =
      []
      |> generator_flag(generator)
      |> generator_dir_flag(@priv_dir)

    cmd_opts = Keyword.fetch!(opts, :cmd_opts)

    with :ok <- File.mkdir_p!(generator_dir) do
      case System.cmd(cmd, args, cmd_opts) do
        {_, 0} -> :ok
        {_, code} -> {:error, {:generate_error, code}}
      end
    end
  end

  defp generator_flag(args, generator) when is_binary(generator),
    do: ["-G #{generator}" | args]

  defp generator_flag(args, _),
    do: args

  defp generator_dir_flag(args, priv_dir),
    do: ["-DCMAKE_LIBRARY_OUTPUT_DIRECTORY=#{priv_dir}" | args]

  defp build_cmake(cmd, opts) do
    build_mode = Keyword.fetch!(opts, :build_mode)

    args = build_mode_flag(["--build"], build_mode)

    cmd_opts = Keyword.fetch!(opts, :cmd_opts)

    case System.cmd(cmd, args, cmd_opts) do
      {_, 0} -> :ok
      {_, code} -> {:error, {:compile_error, code}}
    end
  end

  defp build_mode_flag(args, :release), do: ["-DCMAKE_BUILD_TYPE=Release" | args]
  defp build_mode_flag(args, :debug), do: ["-DCMAKE_BUILD_TYPE=Debug" | args]
  defp build_mode_flag(args, _), do: args
end
