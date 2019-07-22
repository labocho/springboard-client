require "logger"

module Springboard
  class Client
    Config = Struct.new(:client, :server, :networks, keyword_init: true)
    class Config
      Client = Struct.new(:log_level, :log_format, keyword_init: true)
      Server = Struct.new(:host, :user, keyword_init: true)
      Network = Struct.new(:name, :type, :gateway, :user, :password, :preshared_key, :ip_range, keyword_init: true)

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

