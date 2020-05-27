defmodule Mix.Tasks.Corail.New do
  @shortdoc "Creates a new Corail project"
  @moduledoc """
  Generates boilerplate for a new Corail project.

  Usage:

  ```
  mix corail.new [--module <Module>] [--name <Name>] [--otp-app <OTP App>]
  ```
  """

  use Mix.Task
  import Mix.Generator

  @basic [
    {:eex, "basic/cmake/Cache.cmake", "cmake/Cache.cmake"},
    {:eex, "basic/cmake/CompilerWarnings.cmake", "cmake/CompilerWarnings.cmake"},
    {:eex, "basic/cmake/ErlangInterface.cmake", "cmake/ErlangInterface.cmake"},
    {:eex, "basic/cmake/Sanitizers.cmake", "cmake/Sanitizers.cmake"},
    {:eex, "basic/cmake/StandardProjectSettings.cmake", "cmake/StandardProjectSettings.cmake"},
    {:eex, "basic/cmake/StaticAnalyzers.cmake", "cmake/StaticAnalyzers.cmake"},
    {:eex, "basic/README.md", "README.md"},
    {:eex, "basic/CMakeLists.txt", "CMakeLists.txt"},
    {:eex, "basic/.clang-format", ".clang-format"},
    {:eex, "basic/.clang-tidy", ".clang-tidy"},
    {:eex, "basic/.cmake-format.yaml", ".cmake-format.yaml"},
    {:eex, "basic/src/CMakeLists.txt", "src/CMakeLists.txt"},
    {:eex, "basic/src/nif.cpp", "src/nif.cpp"}
  ]

  root = Path.join(:code.priv_dir(:corail), "templates/")

  for {format, source, _} <- @basic do
    unless format == :keep do
      @external_resource Path.join(root, source)
      defp render(unquote(source)), do: unquote(File.read!(Path.join(root, source)))
    end
  end

  @switches [module: :string, name: :string, otp_app: :string]

  @impl true
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: @switches)

    unless module = opts[:module] do
      prompt(
        "This is the name of the Elixir module the NIF module will be registered to.\n" <>
          "Module name"
      )
    end

    unless name = opts[:name] do
      prompt(
        "This is the name used for the generated CMake project. The default is most likely fine.\n" <>
          "Library name",
        format_module_name_as_name(module)
      )
    end

    otp_app =
      case opts[:otp_app] do
        nil -> Mix.Project.config() |> Keyword.get(:app)
        otp_app -> otp_app
      end

    check_module_name_validity!(module)

    path = Path.join([File.cwd!(), "native/", name])
    new(otp_app, path, module, name, opts)
  end

  defp new(otp_app, path, module, name, _opts) do
    module_elixir = "Elixir." <> module

    binding = [
      otp_app: otp_app,
      project_name: module_elixir,
      native_module: module_elixir,
      module: module,
      library_name: name
    ]

    copy_from(path, binding, @basic)

    Mix.Shell.IO.info([:green, "Ready to go! See #{path}/README.md for further instructions."])
  end

  defp check_module_name_validity!(name) do
    unless name =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/ do
      Mix.raise(
        "Module name must be a valid Elixir alias (for example: Foo.Bar), got: #{inspect(name)}"
      )
    end
  end

  defp format_module_name_as_name(module_name),
    do: String.replace(String.downcase(module_name), ".", "_")

  defp copy_from(target_dir, binding, mapping) when is_list(mapping) do
    for {format, source, target_path} <- mapping do
      target = Path.join(target_dir, target_path)

      case format do
        :keep ->
          File.mkdir_p!(target)

        :text ->
          create_file(target, render(source))

        :eex ->
          contents = EEx.eval_string(render(source), binding, file: source)
          create_file(target, contents)
      end
    end
  end

  defp prompt(message) do
    Mix.Shell.IO.print_app()
    resp = IO.gets(IO.ANSI.format([message, :white, " > "]))
    ?\n = :binary.last(resp)
    :binary.part(resp, {0, byte_size(resp) - 1})
  end

  defp prompt(message, default) do
    response = prompt([message, :white, " (", default, ")"])

    case response do
      "" -> default
      _ -> response
    end
  end
end
