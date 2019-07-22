require "springboard/client/version"
require "base64"
require "yaml"
require "net/ssh"
require "shellwords"
require "open3"
require "logger"
require "json"
require "rainbow"

module Springboard
  class Client
    require_relative "client/cli"
    require_relative "client/config"
    require_relative "client/session"

    class Error < StandardError; end

    CONFIG_FILE = "#{ENV["HOME"]}/.springboard.yml".freeze

    attr_reader :config, :logger

    def self.load(config_overrides = {})
      raise "Config file not found" unless File.exist?(CONFIG_FILE)

      config = Config.parse(deep_merge!(YAML.load_file(CONFIG_FILE), config_overrides))
      new(config)
    end

    def self.deep_merge!(h1, h2)
      h2.each do |k, v|
        h1[k] = case v
        when Hash
          deep_merge!(h1[k], v)
        else
          v
        end
      end
      h1
    end

    def initialize(config)
      @config = config

      log_formatter = case config.client.log_format
      when "json"
        Rainbow.enabled = false
        json_log_formatter
      when "default"
        default_log_formatter
      else
        raise "Unknown log format: #{config.client.log_format.inspect}"
      end

      Rainbow.enabled = false unless $stderr.tty?
      @logger = Logger.new(
        $stderr,
        formatter: log_formatter,
        level: config.client.log_level,
      )
    end

    def connect(name)
      network = config.networks.find {|n| n.name == name } || raise("Network named #{name.inspect} not found")
      Session.start(config.server, network, logger)
    end

    def default_log_formatter
      -> (_severity, time, _progname, msg) {
        Rainbow("[#{time}]").dimgray + " " + msg + "\n"
      }
    end

    def json_log_formatter
      -> (severity, time, progname, msg) {
        {severity: severity, time: time, progname: progname, msg: msg}.to_json + "\n"
      }
    end
  end
end
