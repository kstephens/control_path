require 'uuid'
require 'digest/sha1'

module ControlPath
  module Random
    def new_token
      hex_to_base64(digest(new_uuid)).gsub(/[^a-z0-9]+/i, '')
    end

    def digest str
      Digest::SHA1.hexdigest(str)
    end

    def hex_to_base64 str
      [[str].pack("H*")].pack("m0")
    end

    def new_uuid
      UUID.new.generate
    end

    def rand interval
      case interval
      when Proc
        interval.call
      when Range
        t = rand_float
        interval.first * (1.0 - t) + interval.last * t
      when Numeric
        interval.to_f
      else
        if interval.respond_to?(:call)
          interval.call
        end
      end
    end

    def rand_float
      Kernel.rand
    end

    extend self
  end
end
