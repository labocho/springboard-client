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
    require_relative "client/config"

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

      logger.info "Try to connect springboard server #{config.server.user}@#{config.server.host}"
      Net::SSH.start(config.server.host, config.server.user) do |session|
        @session = session
        logger.info "Connected to springboard server"

        begin
          create_connection(network) do
            logger.info "Try to connect network #{network.name}"
            activate_connection(network) do
              create_route(network) do
                logger.info "Connected network #{network.name} (ctrl+c to disctonnect)"
                sleep
              end
            end
          end
        rescue SignalException
          raise unless Signal.signame($!.signo) == "INT"
        end

        logger.info "Disconnected"
      end
    end

    private
    def ssh(cmd_and_args)
      raise "SSH not started" unless @session

      joined = cmd_and_args.shelljoin
      logger.debug "(remote) #{joined}"
      _ = @session.exec!(joined)
    end

    def sh(cmd_and_args)
      joined = cmd_and_args.shelljoin
      logger.debug "(local) #{joined}"
      o, e, s = Open3.capture3(joined)

      unless s.success?
        raise "Command ${joined.inspect} exited with #{s.exitstatus}: #{e}"
      end

      o
    end

    def nmcli_config_hash_to_array(hash)
      hash.flat_map do |k, v|
        k = k.to_s.gsub("_", "-")

        if v.is_a?(Hash)
          v = v.map {|hk, hv|
            hk = hk.to_s.gsub("_", "-")
            "#{hk}=#{hv}"
          }.join(",")
        end

        [k, v]
      end
    end

    def create_connection(network)
      ssh add_connection_cmd(network)
      yield
    ensure
      ssh delete_connection_cmd(network)
    end

    def activate_connection(network)
      ssh up_connection_cmd(network)
      yield
    ensure
      ssh down_connection_cmd(network)
    end

    def create_route(network)
      sh add_route_cmd(network)
      yield
    ensure
      sh delete_route_cmd(network)
    end

    def add_connection_cmd(network)
      [
        "sudo", "nmcli", "connection", "add",
        *nmcli_config_hash_to_array(
          type: "vpn",
          ifname: "*",
          con_name: network.name,
          save: "no",
          vpn_type: "l2tp",
          user: network.user,
        ),
        "--",
        *nmcli_config_hash_to_array(
          "vpn.data": {
            gateway: network.gateway,
            ipsec_enabled: "yes",
            ipsec_psk: "0s" + Base64.strict_encode64(network.preshared_key),
            password_flags: "0",
          },
          "vpn.secrets": {
            password: network.password,
          },
          "connection.zone": "external",
        ),
      ]
    end

    # nmcli connection up {network.name} で接続
    def up_connection_cmd(network)
      ["sudo", "nmcli", "connection", "up", network.name]
    end

    # nmcli connection down {network.name} で接続解除
    def down_connection_cmd(network)
      ["sudo", "nmcli", "connection", "down", network.name]
    end

    # nmcli connection delete {network.name} で削除
    def delete_connection_cmd(network)
      ["sudo", "nmcli", "connection", "delete", network.name]
    end

    def add_route_cmd(network)
      [
        "sudo",
        "route",
        "add",
        "-net",
        network.ip_range,
        config.server.host,
      ]
    end

    def delete_route_cmd(network)
      [
        "sudo",
        "route",
        "delete",
        "-net",
        network.ip_range,
        config.server.host,
      ]
    end
  end
end
