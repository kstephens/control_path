require 'control_path/service'
require 'control_path/json'
require 'fileutils'
require 'time'
require 'uuid'
require 'awesome_print'
require 'digest/sha1'

module ControlPath::Service
  class Controller
    attr_accessor :store, :logger

    def initialize opts
      @logger = opts[:logger]
      @store = opts[:store] or raise ArgumentError
    end

    CONTROL = 'control.json'.freeze
    STATUS  = 'status.json'.freeze

    def fetch_status! path
      files = store.children(path, STATUS)
      files.map do | file |
        control, controls = merged_controls(file[:path])
        status = store.read(file[:path], STATUS)
        control_version = control && control[:version]
        seen_version = status[:seen_version]
        status = status.merge(seen_current_version: control_version.to_s == seen_version.to_s)
        { path: file[:path],
          status: status,
          control: control,
          controls: controls,
        }
      end
    end

    def get_control! path
      begin
        store.read(path, CONTROL)
      rescue => exc
        nil
      end
    end

    def fetch_control! path
      result = { status: 'UNKNOWN', path: path }
      begin
        merged, controls = merged_controls(path)
        result = result.merge(control: merged)
        result[:status] = 'OK'
      rescue => exc
        logger.error exc
        result[:status] = 'API-ERROR'
      end
      result
    end

    def put_control! path, data
      control =
        control_header.
        merge(data: data).
        merge(control_footer)
      store.write!(path, CONTROL, control)
      control
    end

    def patch_control! path, data
      control =
        control_header.
        merge(store.read(path, CONTROL))
      merged_data =
        merge_data(control[:data], data)
      control =
        control.
        merge(data: merged_data).
        merge(control_footer)
      store.write!(path, CONTROL, control)
      control
    end

    def delete_control! path
      begin
        control = store.read(path, CONTROL)
        store.delete!(path, CONTROL)
        control
      rescue => exc
        logger.error exc
        nil
      end
    end

    def update_status! path, control, request, params
      seen_version = params[:version]
      interval = params[:interval]
      host = params[:host]
      status = {
        time: format_time(now),
        client_ip: request.ip.to_s,
        path: path,
        seen_version: seen_version,
        seen_current_version: nil,
        host: host,
        interval: interval && interval.to_f,
        params: params,
      }
      store.write!(path, STATUS, status)
    end

    # Implementation:

    def merged_controls path
      files = store.parents(path, CONTROL)
      files.reverse!
      merged = { }
      controls = [ ]
      files.each do | file |
        data = store.read(file[:path], CONTROL)
        merged = merge_control(merged, data)
        controls << {
          path: file[:path],
          time: data[:time],
          version: data[:version],
        }
      end
      [ merged, controls ]
    end

    def merge_control merged, data
      merged_version =
        merged[:version] ?
        digest("#{merged[:version]}|#{data[:version]}") :
        data[:version]
      merged_time =
        merged[:time].to_s > data[:time].to_s ?
        merged[:time] :
        data[:time]
      merged_data = merge_data(merged[:data], data[:data])
      merged.update(data)
      merged[:version] = merged_version
      merged[:time]    = merged_time
      merged[:data]    = merged_data
      merged
    end

    def merge_data a, b
      result = (a || { }).
        merge( (b || { }) )
      result.dup.each do | k, v |
        result.delete(k) if DELETE == v
      end
      result
    end
    DELETE = '__DELETE__'.freeze

    def control_header
      { time: "", version: "" }
    end

    def control_footer
      { time: format_time(now), version: new_version }
    end

    def now
      Time.now.utc
    end

    def new_version
      digest(new_uuid)
    end

    def digest str
      Digest::SHA1.hexdigest(str)
    end

    def new_uuid
      UUID.new.generate
    end

    def format_time time
      time.getutc.iso8601(3)
    end

    def logger
      @logger ||= ::Logger.new($stderr)
    end

  end
end

