require 'control_path/service'
require 'control_path/json'
require 'fileutils'
require 'time'
require 'uuid'
require 'awesome_print'
require 'digest/sha1'

module ControlPath::Service
  class Store
    include ControlPath::Json
    attr_accessor :dir, :file_system, :logger

    def initialize opts
      @dir = opts[:dir] or raise ArgumentError
      @file_system = opts[:file_system] || ::File
    end

    def fetch_status! path
      files = files_in_children(client_dir, path, "status.json")
      files.map do | file |
        merged, controls = merged_controls(file[:path])
        { path: file[:path],
          status: read_file(file[:file]),
          control: merged,
          controls: controls,
        }
      end
    end

    def get_control! path
      begin
        read_control(path)
      rescue => exc
        nil
      end
    end

    def fetch_control! path
      result = { status: 'UNDEFINED', path: path }
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
        merge(data).
        merge(control_footer)
      write_file(control_file(path), control)
      control
    end

    def patch_control! path, data
      control =
        control_header.
        merge(read_file(control_file(path))).
        merge(data).
        merge(control_footer)
      write_file(control_file(path), control)
      control
    end

    def delete_control! path
      file = control_file(path)
      begin
        control = from_json(file_system.read(file))
        file_system.unlink(control_file(path))
        control
      rescue => exc
        logger.error exc
        nil
      end
    end

    def update_status! path, control, request, params
      seen_version = params[:version]
      seen_current_version = control[:control][:version].to_s == seen_version.to_s
      status = {
        time: format_time(now),
        client_ip: request.ip.to_s,
        path: path,
        seen_version: seen_version,
        seen_current_version: seen_current_version,
        params: params,
      }
      save_status!(path, status)
    end

    # Implementation

    def read_control path
      file_system.read(control_file(path))
    end

    def save_status! path, data
      write_file(status_file(path), data)
    end

    def now
      Time.now.utc
    end

    def client_dir
      @client_dir ||= "#{dir}/client".freeze
    end

    def status_file path
      "#{client_dir}/#{path}/status.json"
    end

    def control_file path
      "#{client_dir}/#{path}/control.json"
    end

    def control_header
      { time: "", version: "" }
    end

    def control_footer
      { time: format_time(now), version: new_version }
    end

    def merged_controls path
      files = files_in_parents(client_dir, path, "control.json")
      files.reverse!
      merged = { }
      controls = [ ]
      files.each do | file |
        data = read_file(file[:file])
        merged_version =
          merged[:version] ?
          digest("#{merged[:version]}|#{data[:version]}") :
          data[:version]
        merged.update(data)
        merged[:version] = merged_version
        controls << {
          path: file[:path],
          time: data[:time],
          version: data[:version],
        }
      end
      [ merged, controls ]
    end

    def files_in_parents base, path, name
      dirs = path_parents(path)
      dirs.map do | dir |
        { file: "#{base}/#{dir}/#{name}",
          path: dir,
          name: name,
        }
      end.select{|f| file_system.exist?(f[:file])}
    end

    def path_parents path
      paths = [ ]
      while path != '.'
        paths.push path
        path = File.dirname(path)
      end
      paths
    end

    def files_in_children base, path, name
      Dir["#{base}/#{path}/**/#{name}"].sort.map do | file |
        rx = %r{\A#{Regexp.quote(base)}/(.+?)/#{Regexp.quote(name)}\Z}
        if m = rx.match(file)
          { file: file,
            path: m[1],
            name: m[2],
          }
        end
      end.compact
    end

    def read_file file
      from_json(file_system.read(file))
    end

    def write_file file, data
      content = to_json(data)
      begin
        tmp = "#{file}.#{$$}"
        file_system.mkdir_p(File.dirname(tmp))
        file_system.write(tmp, content)
        file_system.chmod(0644, tmp)
        file_system.rename(tmp, file)
      ensure
        file_system.unlink(tmp) rescue nil
      end
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

class File
  def self.mkdir_p *args
    FileUtils.mkdir_p *args
  end
end
