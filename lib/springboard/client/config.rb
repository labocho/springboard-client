require "logger"

module Springboard
  class Client
    Config = Struct.new(:client, :server, :networks, keyword_init: true)
    class Config
      CONFIG_FILE = "#{ENV["HOME"]}/.springboard.yml".freeze

      Client = Struct.new(:log_level, :log_format, keyword_init: true)
      Server = Struct.new(:host, :port, :user, :vagrant, keyword_init: true)
      Network = Struct.new(:name, :type, :gateway, :user, :password, :preshared_key, :ip_range, :ipsec_remote_id, :ipsec_ike, :ipsec_esp, :require_mppe_128, keyword_init: true)

      def self.parse(string_keyed_hash)
        hash = deep_symbolize_keys(string_keyed_hash)

        hash[:client] ||= {}
        hash[:client][:log_level] = if hash[:client][:log_level]
          Logger::Severity.const_get(hash[:client][:log_level])
        else
          Logger::Severity::INFO
        end
        hash[:client][:log_format] = hash[:client][:log_format]

        hash[:client] = Client.new(hash[:client] || {}).freeze
        hash[:server] = Server.new(hash[:server]).freeze
        hash[:networks] = hash[:networks].map {|h| Network.new(h).freeze }.freeze
        new(hash).freeze
      end

      def self.load(config_overrides = {})
        raise "Config file not found" unless File.exist?(CONFIG_FILE)

        Config.parse(deep_merge!(YAML.unsafe_load(File.read(CONFIG_FILE)), config_overrides))
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

      def self.deep_symbolize_keys(o)
        case o
        when Hash
          o.each_with_object({}) do |(k, v), h|
            h[k.to_sym] = deep_symbolize_keys(v)
          end
        when Array
          o.map {|e| deep_symbolize_keys(e) }
        else
          o
        end
      end
    end
  end
end
