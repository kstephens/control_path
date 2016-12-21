require 'oj'
require 'multi_json'

module ControlPath
  module Json
    def to_json data
      MultiJson.dump(data, pretty: true)
    end

    def from_json content
      MultiJson.load(content, symbolize_keys: true)
    end

    extend self
  end
end
