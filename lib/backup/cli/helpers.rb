# encoding: utf-8

module Backup
  module CLI
    module Helpers
      UTILITY = {}

      ##
      # Runs a system command
      #
      # All messages generated by the command will be logged.
      # Messages on STDERR will be logged as warnings.
      #
      # If the command fails to execute, or returns a non-zero exit status
      # an Error will be raised.
      #
      # Returns STDOUT
      def run(command)
        name = command_name(command)
        Logger.message "Running system utility '#{ name }'..."

        begin
          out, err = '', ''
          # popen4 doesn't work in 1.8.7 with stock versions of ruby shipped
          # with major OSs. Hack to make it stop segfaulting.  
          # See: https://github.com/engineyard/engineyard/issues/115
          GC.disable
          ps = Open4.popen4(command) do |pid, stdin, stdout, stderr|
            stdin.close
            out, err = stdout.read.strip, stderr.read.strip
          end
        rescue Exception => e
          raise Errors::CLI::SystemCallError.wrap(e, <<-EOS)
            Failed to execute system command on #{ RUBY_PLATFORM }
            Command was: #{ command }
          EOS
        ensure
          GC.enable
        end

        if ps.success?
          unless out.empty?
            Logger.message(
              out.lines.map {|line| "#{ name }:STDOUT: #{ line }" }.join
            )
          end

          unless err.empty?
            Logger.warn(
              err.lines.map {|line| "#{ name }:STDERR: #{ line }" }.join
            )
          end

          return out
        else
          raise Errors::CLI::SystemCallError, <<-EOS
            '#{ name }' Failed on #{ RUBY_PLATFORM }
            The following information should help to determine the problem:
            Command was: #{ command }
            Exit Status: #{ ps.exitstatus }
            STDOUT Messages: #{ out.empty? ? 'None' : "\n#{ out }" }
            STDERR Messages: #{ err.empty? ? 'None' : "\n#{ err }" }
          EOS
        end
      end


      ##
      # Returns the full path to the specified utility.
      # Raises an error if utility can not be found in the system's $PATH
      def utility(name)
        name = name.to_s.strip
        raise Errors::CLI::UtilityNotFoundError,
            'Utility Name Empty' if name.empty?

        path = UTILITY[name] || %x[which #{ name } 2>/dev/null].chomp
        if path.empty?
          raise Errors::CLI::UtilityNotFoundError, <<-EOS
            Could not locate '#{ name }'.
            Make sure the specified utility is installed
            and available in your system's $PATH.
          EOS
        end
        UTILITY[name] = path
      end

      ##
      # Returns the name of the command name from the given command line
      def command_name(command)
        i = command =~ /\s/
        command = command.slice(0, i) if i
        command.split('/')[-1]
      end

    end
  end
end
