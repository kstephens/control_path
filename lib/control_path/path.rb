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
      elems = \
      case path
      when Array
        path.map(&:to_s)
      else
        path.to_s.split('/', 9999)
      end
      head = elems.shift if elems[0]  && elems[0] .empty?
      tail = elems.pop   if elems[-1] && elems[-1].empty?
      elems =
        elems.
        map{|k| k =~ /^(\d+)$/ ? $1.to_i : k.to_sym }.
        reject{|k| k == :'' || k == :'.' || k == :'/' }
      elems.unshift head.to_sym if head
      elems.push    tail.to_sym if tail
      elems
    end

    def inspect
      "#{self.class}[#{to_s.inspect}]"
    end

    def to_s
      @elements * '/'
    end

    def absolute?
      @elements.first == :''
    end

    def deep?
      @elements[-1] == :''
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
        traverse! root, Path[''], path
        @result
      ensure
        @blk = nil
      end

      def traverse! node, dir, path
        rest = path.rest
        case name = path.first
        when nil
        when :'*'
          traverse_children! node, dir, rest
        else
          if pat = pattern?(name)
            children(node).each do | name |
              if pat === name.to_s
                emit_or_traverse! node, dir, name, rest
              end
            end
          else
            emit_or_traverse! node, dir, name, rest
          end
        end
      end

      def emit_or_traverse! node, dir, name, rest
        if rest.empty?
          if exists?(node, name)
            emit! dir, name
          end
        else
          traverse! child(node, name), dir / name, rest
        end
      end

      def traverse_children! node, dir, rest
        children(node).each do | name |
          emit_or_traverse! node, dir, name, rest
        end
      end

      def pattern? name
        p = name.to_s
        if p.gsub!(/\*/, ".*")
          Regexp.new("\\A#{p}\\Z")
        end
      end

      def emit! dir, name
        @blk.call(dir, name)
      end

      def children node
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
