require 'control_path/service'
require 'control_path/json'
require 'sinatra'
require 'sinatra/namespace'
require 'awesome_print'
require 'time' # iso8601
require 'logger'

module ControlPath::Service
  class Application < Sinatra::Base
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
    set :reload_templates , false
    #set :sessions       , true
    #set :session_secret , '12341234' # FIXME

    def initialize opts = { }
      @logger = opts[:logger] || ::Logger.new($stderr)
      @store  = opts[:store] || ControlPath::Service::Store.new(dir: "#{Constants.public_dir}/data", logger: logger)
    end
    attr_accessor :store, :logger

    PATH_RX = %r{^/(.+?)/?}

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
            control = store.fetch_control!(path)
            begin
              status = { time: now, client_ip: request.ip.to_s, path: path }
              store.save_status!(path, status)
            rescue => exc
              logger.error exc
              control[:status] = 'API-ERROR'
            end
            json_body control
          end
        end

        namespace '/status' do
          get PATH_RX do
            status = store.fetch_status!(path)
            json_body(server_metadata.merge(status: status))
          end
        end

        namespace '/control' do
          get PATH_RX do
            if control = get_control!(path)
              json_body(control)
            else
              404
            end
          end
          put PATH_RX do
            control = store.put_control!(path, from_json(request.body))
            json_body control
          end
          patch PATH_RX do
            control = store.patch_control!(path, from_json(request.body))
            json_body control
          end
          delete PATH_RX do
            if control = store.delete_control!(path)
              json_body(control)
            else
              404
            end
          end
        end

      helpers do
        include Constants, ControlPath::Json

        def server_metadata
          @server_metadata ||= {
            now: format_time(now),
            host: Socket.gethostname,
            pid: $$,
          }.freeze
        end

        def now
          @now ||= Time.now.utc
        end

        def path
          @path ||= params['captures'].first.gsub(%r{/+}, '/').freeze
        end

        def format_time time
          store.format_time(time)
        end

        def json_body data, raw = false
          content = raw ? data : to_json(data)
          [ 200, { 'Content-Type' => 'application/json' }, [ content.to_s ] ]
        end

      end
    end
  end
end
