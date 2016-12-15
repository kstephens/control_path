current_dir = ::File.expand_path('..', __FILE__)
$:.unshift(::File.join(current_dir, 'lib'))

if defined? ::Unicorn
  require 'unicorn/worker_killer'
  use Unicorn::WorkerKiller::MaxRequests, 1000, 1200
  use Unicorn::WorkerKiller::Oom, (700*(1024**2)), (800*(1024**2)), 1, true
end

require 'control_path/service'
require 'awesome_print'
require 'rack_console/app'

use Rack::Reloader unless ENV['RACK_ENV'] == 'production'
use Rack::MethodOverride

service = ControlPath::Service.new
run Rack::URLMap.
  new(
      "/__console__" =>
      RackConsole::App.new(
                               eval_target: service,
                               awesome_print: true,
                               url_root_prefix: "/__console__",
                               views: [ :default ]),
      "/" => service,
      )
