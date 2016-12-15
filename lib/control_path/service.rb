require 'control_path'
require 'control_path/json'
require 'sinatra'
require 'sinatra/namespace'
require 'fileutils'
require 'time'
require 'uuid'
require 'awesome_print'

module ControlPath
  class Service < Sinatra::Base
    register Sinatra::Namespace

    module Constants
      def root_dir
        File.expand_path('../../../..', __FILE__).freeze
      end
      def public_dir
        "#{root_dir}/public"
      end
      def tmp_dir
        "#{root_dir}/tmp"
      end
      extend self
    end

    set :app_file       , __FILE__
    set :root           , Constants.root_dir
    set :public_folder  , Constants.public_dir
    set :tmp_folder     , Constants.tmp_dir
    set :static         , true
    #set :sessions       , true
    #set :session_secret , '12341234' # FIXME

    PATH_RX = %r{^/(.+?)/?}

    namespace '/admin' do
      namespace '/api' do
        get '/?' do
          endpoints = {
            '/admin/api/client/PATH' => {
              methods: [ 'GET' ],
              description: "Clients GET their PATH; if the content changed since last GET, clients are expected to act.",
            },
            '/admin/api/status/PATH'  => {
              methods: [ 'GET' ],
              description: "Returns status of client GETs.",
            },
            '/admin/api/control/PATH' => {
              methods: [ 'GET', 'PUT', 'PATCH', 'DELETE' ],
              description: "GET, PUT, PATCH or DELETE the control for PATH.",
            },
          }
          json_body(server_metadata.merge(endpoints: endpoints))
        end

        namespace '/client' do
          get PATH_RX do
            control = { status: 'UNDEFINED', path: path }
            begin
              status = { time: now, client_ip: request.ip.to_s, path: path }
              write_file(status_file(path), status)
              control = control.merge(read_control(path))
            rescue
              control[:status] = 'API-ERROR'
            end
            json_body control
          end
        end

        namespace '/status' do
          get PATH_RX do
            files = locate_files(client_dir, "#{path}/status.json")
            result =
              files.map do | file |
              { path: file[:path],
                status: read_file(file[:file]),
                control: read_control(file[:path]),
              }
            end
            json_body(server_metadata.merge(status: result))
          end
        end

        namespace '/control' do
          get PATH_RX do
            begin
              json_body(File.read(control_file(path)), :raw)
            rescue => exc
              404
            end
          end
          put PATH_RX do
            control = put_control(path, from_json(request.body))
            json_body control
          end
          patch PATH_RX do
            control = patch_control(path, from_json(request.body))
            json_body control
          end
          delete PATH_RX do
            file = control_file(path)
            begin
              control = File.read(file)
              File.unlink(control_file(path))
              json_body(control, :raw)
            rescue => exc
              404
            end
          end
        end
      end

      helpers do
        include Constants, Json
        def server_metadata
          @server_metadata ||= {
            now: format_time(now),
            host: Socket.gethostname,
            pid: $$,
          }.freeze
        end
        def client_dir
          @client_dir ||= "#{public_dir}/data/client".freeze
        end
        def now
          @now ||= Time.now.utc
        end
        def path
          @path ||= params['captures'].first.gsub(%r{/+}, '/').freeze
        end

        def status_file path
          "#{client_dir}/#{path}/status.json"
        end

        def control_file path
          "#{client_dir}/#{path}/control.json"
        end

        def patch_control path, data
          control = control_header.merge(read_control(path)).merge(data).merge(control_footer)
          write_file(control_file(path), control)
          control
        end

        def put_control path, data
          control = control_header.merge(data).merge(control_footer)
          write_file(control_file(path), control)
          control
        end

        def control_header
          { time: "", version: "" }
        end

        def control_footer
          { time: format_time(now), version: new_uuid }
        end

        def read_control path
          data = { status: 'UNDEFINED' }
          begin
            if control_file = locate_file(client_dir, "#{path}/control.json")
              data = read_file(control_file[:file])
              data = data.merge(control: { path: control_file[:path] })
            else
              data[:status] = 'NOT-FOUND'
            end
          rescue
            data[:status] = 'API-ERROR'
          end
          data = data.merge(path: path)
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
            # ap(file: file, rx: rx)
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
          time.iso8601(3)
        end

        def json_body data, raw = false
          content = raw ? data : to_json(data)
          [ 200, { 'Content-Type' => 'application/json' }, [ content.to_s ] ]
        end

      end
    end
  end
end

