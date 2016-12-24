module ControlPath
  class Path
    include Enumerable

    class << self
      alias :[] :new
    end

    attr_reader :value, :elements

    def initialize x
      @value = x
      @elements = parse(x)
    end

    def == x
      x = x.elements if self.class === x
      @elements == x
    end

    def parse path
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

    def inspect
      "#<#{self.class} #{to_s}>"
    end

    def to_s
      @elements * '/'
    end

    def method_missing sel, *args, &blk
      @elements.send(sel, *args, &blk)
    end
  end
end
