module Springboard
  class Client
    class Session
      attr_reader :server, :network, :logger

      def self.start(server, network, logger)
        new(server, network, logger).start
      end

      def initialize(server, network, logger)
        @server = server
        @network = network
        @logger = logger
      end

      def start
        host = server.host || ENV["SPRING_BOARD_SERVER_ADDRESS"] || "192.168.33.100"
        user = server.user || "vagrant"
        options = {
          port: server.port || 22
        }
        options[:keys] = ["#{ENV["HOME"]}/.springboard-server/.vagrant/machines/default/virtualbox/private_key"] if server.vagrant

        logger.info "Try to connect springboard server #{user}@#{host}:#{options[:port]}..."

        Net::SSH.start(host, user, **options) do |ssh_session|
          @ssh_session = ssh_session
          logger.info "Connected to springboard server"

          begin
            create_connection do
              logger.info "Try to connect network #{network.name}..."
              activate_connection do
                create_route do
                  logger.info Rainbow("Connected network #{network.name} (#{network.ip_range}) (ctrl+c to disctonnect)").green
                  sleep
                end
              end
            end
          rescue SignalException
            raise unless Signal.signame($!.signo) == "INT"
          end

          logger.info Rainbow("Disconnected").green
        end
      end

      private
      def ssh(cmd_and_args)
        raise "SSH not started" unless @ssh_session

        joined = cmd_and_args.shelljoin
        logger.debug "(remote) #{joined}"
        out = @ssh_session.exec!(joined)

        unless out.exitstatus == 0
          raise "Command #{joined.inspect} via SSH exited with #{out.exitstatus}: #{out}"
        end
      end

      def sh(cmd_and_args)
        joined = cmd_and_args.shelljoin
        logger.debug "(local) #{joined}"
        o, e, s = Open3.capture3(joined)

        unless s.success?
          raise "Command #{joined.inspect} exited with #{s.exitstatus}: #{e}"
        end

        o
      end

      def nmcli_config_hash_to_array(hash)
        hash.flat_map {|k, v|
          next if v.nil?

          k = k.to_s.gsub("_", "-")

          if v.is_a?(Hash)
            v = v.map {|hk, hv|
              next if hv.nil?

              hk = hk.to_s.gsub("_", "-")
              "#{hk}=#{hv}".gsub(",", "\\,")
            }.compact.join(",")
          end

          [k, v]
        }.compact
      end

      def create_connection
        ssh add_connection_cmd
        yield
      ensure
        ssh delete_connection_cmd
      end

      def activate_connection
        ssh up_connection_cmd
        yield
      ensure
        ssh down_connection_cmd
      end

      def create_route
        sh add_route_cmd
        yield
      ensure
        sh delete_route_cmd
      end

      def add_connection_cmd
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
              ipsec_esp: network.ipsec_esp, # 複数指定は nmcli の仕様上できなさそう (vpn.data にカンマを含む値を設定できないため)
              ipsec_ike: network.ipsec_ike, # 複数指定は nmcli の仕様上できなさそう (vpn.data にカンマを含む値を設定できないため)
              ipsec_psk: "0s" + Base64.strict_encode64(network.preshared_key),
              ipsec_remote_id: network.ipsec_remote_id,
              refuse_chap: network.require_mppe_128 ? "yes" : nil,
              refuse_eap: network.require_mppe_128 ? "yes" : nil,
              refuse_pap: network.require_mppe_128 ? "yes" : nil,
              require_mppe_128: network.require_mppe_128 ? "yes" : nil,
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
      def up_connection_cmd
        ["sudo", "nmcli", "connection", "up", network.name]
      end

      # nmcli connection down {network.name} で接続解除
      def down_connection_cmd
        ["sudo", "nmcli", "connection", "down", network.name]
      end

      # nmcli connection delete {network.name} で削除
      def delete_connection_cmd
        ["sudo", "nmcli", "connection", "delete", network.name]
      end

      def add_route_cmd
        [
          "sudo",
          "route",
          "add",
          "-net",
          network.ip_range,
          server.host,
        ]
      end

      def delete_route_cmd
        [
          "sudo",
          "route",
          "delete",
          "-net",
          network.ip_range,
          server.host,
        ]
      end
    end
  end
end
