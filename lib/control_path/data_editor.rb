require 'control_path'
require 'control_path/path'

module ControlPath
  class DataEditor
    class Error < ControlPath::Error
      class InvalidPath < self ; end
    end

    class << self
      alias :[] :new
    end

    attr_accessor :data
    def initialize data
      @data = data
    end

    def [] path
      result = data
      parse_path(path).each do | k |
        result = result[k]
      end
      result
    rescue => exc
      raise Error::InvalidPath, "#{path}"
    end

    def []= path, value
      result = root = { data: Modification[self.data] }
      p = parse_path(path)
      p.unshift(:data)
      t = p.pop
      p.each do | k |
        if (v = result[k]).nil?
          v = Modification[result][k] = empty_data(k)
        end
        result = v
      end
      Modification[result][t] = value
      self.data = root[:data]
      value
    rescue => exc
      raise Error::InvalidPath, "#{path}"
    end

    def empty_data k
      case k
      when Integer
        [ ]
      else
        { }
      end
    end

    def parse_path x
      Path[x]
    end

    def modified? o = data
      Modification === o and o.modified?
    end

    module Modification
      attr_accessor :modified
      alias :modified? :modified
      def self.[] o
        o.extend(self)
      end
      def []= k, v
        self.modified = true if self[k] != v
        super
      end
    end
  end
end
