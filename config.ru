current_dir = ::File.expand_path('..', __FILE__)
$:.unshift(::File.join(current_dir, 'lib'))

require 'control_path/service/application'

# Loopback agent on /client/_self_ controls this service process.
begin
  require 'control_path/client/agent'
  require 'control_path/http'

  on_change = lambda do | this, response |
    if x = this.data and x = x[:control] and x = x[:data] and x = x[:signal]
      this.logger.info "Sending #{x} to self #{$$}"
      Process.kill(x, $$)
    end
  end
  ticker = 1
  new_data = lambda do | this, data |
    {
      host: Socket.gethostname,
      pid: $$,
      ticker: ticker += 1,
      description: %q{
To SIGTERM this control_path server process:
  curl -X PUT -d '{"signal":"TERM"}' http://localhost:9090/api/control/_self_}
    }
  end

  http = ControlPath::Http.new
  agent = ControlPath::Client::Agent.
    new(http: http,
        uri: "http://localhost:9090/api/client/_self_",
        interval: (2..15),
        on_change: on_change,
        new_data: new_data,
        ).test!
  thr = Thread.new do | thr |
    agent.run!
  end
end


use Rack::Reloader unless ENV['RACK_ENV'] == 'production'
use Rack::MethodOverride

run ControlPath::Service::Application.new
