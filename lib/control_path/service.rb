require 'control_path'
module ControlPath
  module Service
    class Error < ControlPath::Error ; end
  end
end
require 'control_path/service/controller'
require 'control_path/service/store'
