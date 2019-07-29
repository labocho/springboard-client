# springboard-client

This is springboard client. This connect to springboard server, VPN, and configure route to the server.

## Installation

    $ git clone https://github.com/labocho/springboard-client.git
    $ cd springboard-client
    $ rake install

## Usage

Please make `~/.springboard.yml` like below.

    client:
        log_format: default
        log_level: INFO
    server:
        host: "192.168.x.x" # springboard server host
        user: springboard # springboard server user name
    networks: # vpn configuration
        - name: test-vpn
          type: l2tp
          gateway: test-vpn.example.com
          user: vpnuser
          password: vpnpass
          preshared_key: presharedkey
          ip_range: "192.168.x.0/24"
          # ipsec_remote_id: "192.168.x.1"
          # ipsec_ike: aes256-sha1
          # ipsec_esp: aes256-sha1
          # require_mppe_128: false

And run `springboard` to connect VPN. Press Ctrl+C to disconnect.

     $ springboard test-vpn

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/labocho/springboard-client.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
