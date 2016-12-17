require 'control_path/service'
require 'control_path/json'
require 'sinatra'
require 'sinatra/namespace'
require 'logger'

module ControlPath::Service
  class Application < Sinatra::Base
    register Sinatra::Namespace

    ROOT_DIR = File.expand_path('../../../..', __FILE__).freeze
    PUBLIC_DIR = "#{ROOT_DIR}/public"

    set :app_file       , __FILE__
    set :root           , ROOT_DIR
    set :public_folder  , PUBLIC_DIR
    set :tmp_folder     , "#{ROOT_DIR}/tmp"
    # Workaround: NoMethodError at undefined method `clear' for nil:NilClass
    set :reload_templates, false

    def initialize opts = { }
      @logger = opts[:logger] || ::Logger.new($stderr)
      @store  = opts[:store] ||
        ControlPath::Service::Store.
        new(dir: "public/data",
            logger: logger)
    end
    attr_accessor :store, :logger

    PATH_RX = %r{^/(.+?)/?}

    namespace '/api' do
      get '/?' do
        endpoints = {
          '/api/client/PATH' => {
            methods: [ 'GET' ],
            description: "Clients GET their PATH; if the content changed since last GET, clients are expected to act.",
          },
          '/api/status/PATH'  => {
            methods: [ 'GET' ],
            description: "Returns status of client GETs.",
          },
          '/api/control/PATH' => {
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
            store.update_status!(path, control, request, clean_params)
          rescue => exc
            logger.error exc
            control[:status] = 'API-ERROR'
          end
          json_body control
        end
      end

      namespace '/client-' do
        get PATH_RX do
          control = store.fetch_control!(path)
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
          if control = store.get_control!(path)
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
        include ControlPath::Json

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

        def clean_params params = self.params
          h = { }
          params.each do | k, v |
            h[k.to_sym] = v
          end
          h.delete(:splat)
          h.delete(:captures)
          h
        end
      end
    end
  end
end
