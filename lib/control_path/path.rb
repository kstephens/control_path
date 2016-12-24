require 'control_path'

module ControlPath
  class Path
    include Enumerable

    def self.[] x = [ ]
      case x
      when self
        x
      else
        new(x)
      end
    end

    attr_reader :value, :elements

    def initialize x
      @value = x
      @elements = parse(x)
    end

    def == x
      @elements == x.to_a
    end

    def hash
      @elements.hash
    end

    def to_a
      @elements
    end

    def / x
      Path[@elements + Path[x].to_a]
    end

    def rest
      Path[@elements[1 .. -1]]
    end

    def parse path
      case path
      when Array
        path.map(&:to_s)
      else
        path.to_s.split('/', 9999)
      end.
        compact.
        map{|k| k =~ /^(\d+)$/ ? $1.to_i : k.to_sym }.
        reject{|k| k == :'' || k == :'.' || k == :'/' }
    end

    def inspect
      "#{self.class}[#{to_s.inspect}]"
    end

    def to_s
      @elements * '/'
    end

    def method_missing sel, *args, &blk
      @elements.send(sel, *args, &blk)
    end

    def glob root
      Globber.new.glob(root, self)
    end

    class Globber
      def glob root, path, &blk
        unless blk
          @result = [ ]
          blk = lambda {|dir, name| @result << (dir / name)}
        end
        @blk = blk
        traverse! root, Path[''], path, false
        @result
      ensure
        @blk = nil
      end

      def traverse! node, dir, path, deep
        rest = path.rest
        case name = path.first
        when nil
        when :'*'
          dir(node).each do | name |
            if rest.empty?
              emit!(dir, name)
            else
              traverse! child(node, name), dir / name, rest, deep
            end
          end
        when :'**'
          dir(node).each do | name |
            traverse! child(node, name), dir / name, rest, true
          end
        else
          if exists?(node, name)
            if rest.empty?
              emit!(dir, name)
            else
              traverse! child(node, name), dir / name, rest, deep
            end
          else
            if deep
              dir(node).each do | name |
                traverse! child(node, name), dir / name, rest, deep
              end
            end
          end
        end
      end

      def emit! dir, name
        @blk.call(dir, name)
      end

      def dir node
        node.respond_to?(:keys) ? node.keys.sort : [ ]
      end

      def exists? node, name
        node.respond_to?(:key?) and node.key?(name)
      end

      def child node, name
        node[name]
      end
    end
  end
end
