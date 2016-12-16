require 'control_path/service'
require 'control_path/json'
require 'fileutils'
require 'time'
require 'uuid'

module ControlPath::Service
  class Store
    include ControlPath::Json
    attr_accessor :dir, :logger

    def initialize opts
      @dir = opts[:dir] or raise ArgumentError
    end

    def fetch_status! path
      files = locate_files(client_dir, "#{path}/status.json")
      result =
        files.map do | file |
        { path: file[:path],
          status: read_file(file[:file]),
          control: read_control(file[:path]),
        }
      end
    end

    def get_control! path
      begin
        json_body(File.read(control_file(path)), :raw)
      rescue => exc
        nil
      end
    end

    def fetch_control! path
      control = { status: 'UNDEFINED', path: path }
      begin
        control = control.merge(read_control(path))
      rescue => exc
        logger.error exc
        control[:status] = 'API-ERROR'
      end
      control
    end

    def put_control! path, data
      control = control_header.merge(data).merge(control_footer)
      write_file(control_file(path), control)
      control
    end

    def patch_control! path, data
      control = control_header.merge(read_control(path)).merge(data).merge(control_footer)
      write_file(control_file(path), control)
      control
    end

    def delete_control! path
      file = control_file(path)
      begin
        control = from_json(File.read(file))
        File.unlink(control_file(path))
        control
      rescue => exc
        logger.error exc
        nil
      end
    end

    def update_status! path, control, request, params
      seen_version = params[:version]
      seen_current_version = control[:version].to_s == seen_version.to_s
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
      { time: format_time(now), version: new_uuid }
    end

    def read_control path
      data = { status: 'UNDEFINED' }
      control = { status: 'UNDEFINED', path: path }
      begin
        if control_file = locate_file(client_dir, "#{path}/control.json")
          data = read_file(control_file[:file])
          control = { path: control_file[:path] }
        else
          control = { status: 'NOT-FOUND', path: path }
        end
      rescue => exc
        logger.error exc
        data[:status] = control[:status] = 'API-ERROR'
      end
      data = data.merge(path: path, control: control)
      # pp(read_control: { path: path, data: data })
      data
    end

    def locate_file base, path
      dir = File.dirname(path)
      name = File.basename(path)
      dirs = [ ]
      while dir != '.'
        dirs.push dir
        dir = File.dirname(dir)
      end
      dirs.map do | dir |
        { file: "#{base}/#{dir}/#{name}",
          path: dir,
          name: name,
        }
      end.find{|f| File.exist?(f[:file])}
    end

    def locate_files base, name
      dir = File.dirname(name)
      name = File.basename(name)
      Dir["#{base}/#{dir}/**/#{name}"].sort.map do | file |
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
      from_json(File.read(file))
    end

    def write_file file, data
      content = to_json(data)
      begin
        tmp = "#{file}.#{$$}"
        FileUtils.mkdir_p(File.dirname(tmp))
        File.write(tmp, content)
        File.chmod(0644, tmp)
        File.rename(tmp, file)
      ensure
        File.unlink(tmp) rescue nil
      end
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
