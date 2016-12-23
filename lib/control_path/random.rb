require 'uuid'
require 'digest/sha1'

module ControlPath
  module Random
    def new_version
      digest(new_uuid)
    end

    def digest str
      Digest::SHA1.hexdigest(str)
    end

    def new_uuid
      UUID.new.generate
    end

    extend self
  end
end
