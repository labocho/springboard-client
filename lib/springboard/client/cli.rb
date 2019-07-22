require "optparse"

module Springboard
  class Client
    class CLI
      def self.start(argv)
        new.start(argv)
      end

      def start(argv)
        options = {
          verbose: false
        }

        optparse = OptionParser.new do |o|
          o.banner = "Usage: springboard [options] NETWORK_NAME"
          o.on("-v", "--verbose", TrueClass) {|b| options[:verbose] = b }
          o.parse!(argv)
        end

        unless argv.length == 1
          warn optparse.help
          exit 1
        end

        client = Client.load
        client.logger.level = Logger::Severity::DEBUG if options[:verbose]

        client.connect(argv.first)
      end
    end
  end
end
