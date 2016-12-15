require 'oj'
require 'multi_json'

module ControlPath
  module Json
    def to_json data
      MultiJson.dump(data, pretty: true)
    end

    def from_json data
      MultiJson.load(data, symbolize_keys: true)
    end
  end
end
