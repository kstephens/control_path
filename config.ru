current_dir = ::File.expand_path('..', __FILE__)
$:.unshift(::File.join(current_dir, 'lib'))

require 'control_path/service/application'
require 'awesome_print'
require 'rack_console/app'

use Rack::Reloader unless ENV['RACK_ENV'] == 'production'
use Rack::MethodOverride

service = ControlPath::Service::Application.new
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
