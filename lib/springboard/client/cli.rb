require "optparse"

module Springboard
  class Client
    class CLI
      def self.start(argv)
        new.start(argv)
      end

      def start(argv)
        options = {
          log_format: "default",
          verbose: false,
        }

        optparse = OptionParser.new do |o|
          o.banner = "Usage: springboard [options] NETWORK_NAME"
          o.on("-v", "--verbose", TrueClass) {|b| options[:verbose] = b }
          o.on("-f", "--log-format FORMAT") {|s|
            case s
            when "d", "default"
              options[:log_format] = "default"
            when "j", "json"
              options[:log_format] = "json"
            else
              warn "Unknown log format: #{s.inspect}"
              exit 1
            end
          }
          o.on("-l", "--list-networks") {
            list_networks
            exit
          }
          o.parse!(argv)
        end

        unless argv.length == 1
          warn optparse.help
          exit 1
        end

        config_overrides = {}
        if options[:verbose]
          config_overrides["client"] ||= {}
          config_overrides["client"]["log_level"] = "DEBUG"
        end

        if options[:log_format]
          config_overrides["client"] ||= {}
          config_overrides["client"]["log_format"] = options[:log_format]
        end

        Client.load(config_overrides).connect(argv.first)
      end

      private
      def list_networks
        Config.load.networks.each {|n| puts n.name }
      end
    end
  end
end
