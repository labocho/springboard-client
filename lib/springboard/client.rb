require "springboard/client/version"
require "base64"
require "yaml"
require "net/ssh"
require "shellwords"
require "open3"
require "logger"
require "json"

module Springboard
  class Client
    require_relative "client/cli"
    require_relative "client/config"
    require_relative "client/session"

    class Error < StandardError; end

    CONFIG_FILE = "#{ENV["HOME"]}/.springboard.yml".freeze

    attr_reader :config, :logger

    def self.load
      raise "Config file not found" unless File.exist?(CONFIG_FILE)

      config = Config.parse(YAML.load_file(CONFIG_FILE))
      new(config)
    end

    def initialize(config)
      @config = config

      @logger = Logger.new(
        $stderr,
        formatter: -> (severity, time, progname, msg) {
          {severity: severity, time: time, progname: progname, msg: msg}.to_json + "\n"
        },
        level: config.client.log_level,
      )
    end

    def connect(name)
      network = config.networks.find {|n| n.name == name } || raise("Network named #{name.inspect} not found")
      Session.start(config.server, network, logger)
    end
  end
end
