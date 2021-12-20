require "./command"

module Kilo
  # Initializes a new project directory tree and copies config
  class Init < Command
    include Constants

    def run(
      global_opts : OptionsHash,
      opts : OptionsHash,
      args : Array(String)
    ) : Nil
      name = args[0]

      if File.exists? name
        Cleaner.exit_failure("#{name} already exists")
      else
        init_project(name)
      end
    end

    private def init_project(dir)
      Helper.mkdir(dir)

      Dir.cd(dir) do
        ProjectDirs.each do |d|
          Helper.mkdir(d)
        end

        # Write files
        Embedded::FILES.each_key do |k|
          Embedded.write_user_file(k)
        end

        # Write extra files
        Embedded::EXTRA_FILES.each_key do |k|
          Embedded.write(Embedded.embedded_file(k))
        end

        Dir.glob("scripts/*.*").each do |f|
          File.chmod(f, 0o755)
        end
      end

      STDERR.puts("* Initialized #{dir}".colorize(:green))
    end
  end
end
