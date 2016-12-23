require 'control_path/service'
require 'control_path/json'
require 'erb'
require 'yaml'
require 'logger'
require 'sinatra'
require 'sinatra/base'
require 'sinatra/namespace'

module ControlPath::Service
  class Application < Sinatra::Base
    class Error < ControlPath::Service::Error ; end
    register Sinatra::Namespace

    ROOT_DIR = File.expand_path('../../../..', __FILE__).freeze
    PUBLIC_DIR = "#{ROOT_DIR}/public"

    set :app_file       , __FILE__
    set :root           , ROOT_DIR
    set :static         , true
    set :public_folder  , PUBLIC_DIR
    set :tmp_folder     , "#{ROOT_DIR}/tmp"
    set :views          , "#{ROOT_DIR}/views"
    set :reload_templates, true

    def initialize opts = { }
      super()
      @logger = opts[:logger] || ::Logger.new($stderr)
      @store  = opts[:store] ||
        ControlPath::Service::Store.
        new(dir: "public/data/client",
            logger: logger)
      @controller = opts[:controller] ||
        ControlPath::Service::Controller.
        new(store: @store,
            logger: logger)
    end
    attr_accessor :controller, :logger

    PATH_RX = %r{^(/.*?)/?}

    namespace '/' do
      get '' do
        [ 304, { 'Location' => '/ui/' } ]
      end
      get 'ui' do
        [ 304, { 'Location' => '/ui/' } ]
      end
    end

    namespace '/ui' do
      get PATH_RX do
        erb :'ui', locals: locals
      end
    end

    namespace '/api' do
      error 400..600 do
        data =
          server_metadata.
          merge(status: response.status,
          error: "Error #{response.status}")
        content_type 'application/json'
        response.body = [ Json.to_json(data) ]
        logger.error data.inspect
      end

      get '/?' do
        json_body(server_metadata.
                  merge(documentation))
      end

      namespace '/client' do
        get PATH_RX do
          update_status! :GET
        end
        put PATH_RX do
          update_status! :PUT
        end
        patch PATH_RX do
          update_status! :PATCH
        end
        delete PATH_RX do
          update_status! :DELETE
        end
      end

      namespace '/client-' do
        get PATH_RX do
          control = controller.fetch_control!(path)
          json_body control
        end
        delete PATH_RX do
          if control = controller.fetch_control!(path)
            controller.delete_status!(path)
            json_body control
          else
            404
          end
        end
      end

      namespace '/status' do
        get PATH_RX do
          status = controller.fetch_status!(path)
          json_body(server_metadata.merge(path: path, status: status))
        end
      end

      namespace '/control' do
        get PATH_RX do
          if control = controller.get_control!(path)
            json_body(control)
          else
            404
          end
        end
        put PATH_RX do
          control = controller.put_control!(path, from_json(request.body))
          json_body control
        end
        patch PATH_RX do
          control = controller.patch_control!(path, from_json(request.body))
          json_body control
        end
        delete PATH_RX do
          if control = controller.delete_control!(path)
            json_body(control)
          else
            404
          end
        end
      end

      helpers do
        def update_status! action
          control = controller.fetch_control!(path)
          begin
            data = \
            case action
            when :GET
              nil
            when :PUT, :PATCH
              from_json(request.body)
            when :DELETE
              controller.delete_status!(path)
              action = nil
            else
              raise Error, "invalidate action #{action.inspect}"
            end
            controller.update_status!(action, path, control, request, clean_params, data) if action
          rescue => exc
            logger.error exc
            control[:status] = 'API-ERROR'
          end
          json_body control
        end
      end
    end

    helpers do
      include ControlPath::Json

      def server_metadata
        @server_metadata ||= {
          api_name: api_name,
          api_version: api_version,
          now: format_time(now),
          host: Socket.gethostname,
          pid: $$,
        }.freeze
      end

      def api_name
        @api_name || "control_path"
      end

      def api_version
        @api_version || ControlPath::VERSION
      end

      def now
        @now ||= Time.now.utc
      end

      def path
        @path ||=
          params[:captures].first
          .gsub(%r{/+}, '/').freeze
      end

      def format_time time
        controller.format_time(time)
      end

      def json_body data, raw = false
        content = raw ? data : to_json(data)
        [ 200, { 'Content-Type' => 'application/json' }, [ content.to_s ] ]
      end

      def clean_params params = self.params
        h = { }
        params.each do | k, v |
          h[k.to_sym] = v unless v.nil?
        end
        h.delete(:splat)
        h.delete(:captures)
        h
      end

      def locals
        @locals ||= {
          params: clean_params,
          path: path,
          now: format_time(now),
        }
      end

      def documentation
        YAML.load <<'YAML'
endpoint:
  /api/client/PATH:
    description: "Clients GET their PATH; if the content changed since last GET, clients are expected to act."
    methods: [ GET, PUT, PATCH, DELETE ]
    params:
      version:
        description: "The last seen control 'version', indicating the client is up-to-date."
        required: false
      interval:
        description: "The max seconds until the client polls again."
        required: false
      host:
        description: "The host name of client."
        required: false
  /api/client-/PATH:
     description: "Same as /api/client/PATH, but does not update /api/client/PATH state."
     methods: [ GET, DELETE ]
     params: [ ]
  /api/status/PATH:
     description: "Status of clients under PATH."
     methods: [ GET ]
     params: [ ]
  /api/control/PATH:
     description: "Manipulate control data for PATH."
     methods: [ GET, PUT, PATCH, DELETE ]
     params: [ ]
YAML
      end
    end
  end
end
