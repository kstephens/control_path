require 'control_path/service'
require 'control_path/json'

module ControlPath::Service
  class Store
    attr_accessor :dir
    def initialize opts
      @dir = opts[:dir] || 'public/data'
    end
  end
end
