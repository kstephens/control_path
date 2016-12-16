current_dir = ::File.expand_path('..', __FILE__)
$:.unshift(::File.join(current_dir, 'lib'))

require 'control_path/service/application'

use Rack::Reloader unless ENV['RACK_ENV'] == 'production'
use Rack::MethodOverride

run ControlPath::Service::Application.new
