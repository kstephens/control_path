require 'control_path'

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
      data = { data: Modification[self.data] }
      result = Modification[data]
      p = parse_path(path)
      p.unshift(:data)
      t = p.pop
      p.each do | k |
        Modification[result]
        if (v = result[k]).nil?
          v = result[k] = Modification[empty_data(k)]
        end
        result = v
      end
      result[t] = value
      self.data = data[:data]
      value
    rescue => exc
      binding.pry
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

    def parse_path path
      case path
      when Array
        path.map(&:to_s)
      else
        path.to_s.split('/', 9999)
      end.
        compact.
        map{|k| k =~ /^(\d+)$/ ? $1.to_i : k }.
        reject{|k| k == '' || k == '.' || k == '/' }.
        map(&:to_sym)
    end

    def modified? o = data
      Modification === o and o.modified?
    end

    module Modification
      attr_accessor :modified
      alias :modified? :modified
      def self.[] o
        o.extend(self)
      rescue => exc
        binding.pry
      end
      def []= k, v
        self.modified = true if self[k] != v
        super
      end
    end
  end
end
