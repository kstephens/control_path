module ControlPath
  module Metadata
    def metadata
      @metadata || {
        api_name: api_name,
        api_version: api_version,
        now: format_time(now),
      }.freeze
    end

    def api_name
      @api_name    || "control_path"
    end

    def api_version
      @api_version || ControlPath::VERSION
    end

    def format_time time
      time.getutc.iso8601(3)
    end
  end
end
