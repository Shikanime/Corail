defmodule Corail do
  @moduledoc """
  Provides compile-time configuration for a NIF module.

  When used, Corail expects the `:otp_app` as option.
  The `:otp_app` should point to the OTP application that
  the dynamic library can be loaded from. For example:

      defmodule MyNIF do
        use Corail, otp_app: :my_nif
      end

  This allows the module to be configured like so:

      config :my_nif, MyNIF,
        project: :my_nif,
        load_data: [1, 2, 3]

  ## Configuration options

    * `:cmake` - Specify how to envoke the cmake generator. Options are:
        - `:system` (default) - use `cmake` from the system (must by in `$PATH`)
        - `{:bin, "/path/to/binary"}` - provide a specific path to `cmake`.

    * `:project` - the name of the project, if different from your `otp_app`
      value. If you have more than one project, you will need to
      be explicit about which project you intend to use.

    * `:load_data` - Any valid term. This value is passed into the NIF when it is
      loaded (default: `0`)

    * `:load_path` - This option allows control over where the final artifact should be
      loaded from at runtime. By default the compiled artifact is loaded from the
      owning `:otp_app`'s `priv/native` directory. This option comes in handy in
      combination with the `:skip_compilation` option in order to load pre-compiled
      artifacts. To override the default behaviour specify a tuple:
      `{:my_app, "priv/native/<artifact>"}`. Due to the way `:erlang.load_nif/2`
      works, the artifact should not include the file extension (i.e. `.so`, `.dll`).

    * `:build_mode` - Specify which mode to compile the project with. If you do not specify
      this option, a default will be provide based on the `Mix.env()`:
      - When `Mix.env()` is `:dev` or `:test`, the project will be compiled in `:debug` mode.
      - When `Mix.env()` is `:prod` or `:bench`, the project will be compiled in `:release` mode.

    * `:path` - By default, corail expects the project to be found in `native/<project>` in the
      root of the project. Use this option to override this.

    * `:skip_compilation` - This option skips envoking the compiler. Specify this option
      in combination with `:load_path` to load a pre-compiled artifact.

    * `:generator` - Specify a generator.

    * `:generator_dir`: Override the generator output directory.

    * `:cmd_opts` - Forward options to the cmd when envoking the generator and build.

  Any of the above options can be passed directly into the `use` macro like so:

      defmodule MyNIF do
        use Corail,
          otp_app: :my_nif,
          project: :some_other_crate,
          load_data: :something
      end
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      {otp_app, config} = Keyword.pop(opts, :otp_app)
      {load_data, config} = Keyword.pop(opts, :load_data)

      case Corail.Compiler.compile_cmake(__MODULE__, otp_app, opts) do
        {:ok, {load_path, resources}} ->
          for resource <- resources,
              do: @external_resource(resource)

          @otp_app otp_app
          @load_path load_path
          @load_data load_data

          @before_compile Corail

        {:error, {:generate_error, code}} ->
          raise "CMake NIF build generation error (cmake exit code #{code})"

        {:error, {:compile_error, code}} ->
          raise "CMake NIF compile error (cmake exit code #{code})"
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @on_load :corail_init

      @doc false
      def corail_init do
        # Remove any old modules that may be loaded so we don't get
        # :error, {:upgrade, 'Upgrade not supported by this NIF library.'}}
        :code.purge(__MODULE__)
        load_path = :code.priv_dir(@otp_app) ++ @load_path
        :erlang.load_nif(load_path, @load_data)
      end
    end
  end
end
