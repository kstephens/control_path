require 'control_path/service'
require 'control_path/json'
require 'control_path/metadata'
require 'erb'
require 'yaml'
require 'pp'
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

    PATH_RX = %r{^(/.*)}
    API_ERROR = 'API-ERROR'.freeze

    not_found      do error_response! end
    error 400..600 do error_response! end

    namespace '/' do
      get %r{^(ui)?$} do
        [ 304, { 'Location' => '/ui/' } ]
      end
    end

    namespace '/ui' do
      get PATH_RX do
        erb :'ui', locals: locals
      end
    end

    namespace '/js' do
      get '/:name.js' do
        content_type 'application/javascript'
        erb :"js/#{params[:name]}.js"
      end
    end

    namespace '/api' do
      get '/?' do
        json_body(documentation)
      end

      namespace '/ping' do
        get '/?' do
          json_body(ping: "pong")
        end
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
          json_body(path: path, status: status)
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
            control[:status] = API_ERROR
          end
          json_body control
        end
      end
    end

    helpers do
      include ControlPath::Json, ControlPath::Metadata

      def server_metadata
        @server_metadata ||=
          metadata.
          merge(host: Socket.gethostname,
                pid: $$,
                )
      end

      def now
        @now ||= Time.now.utc
      end

      def path
        @path ||=
          (x = params[:captures]) &&
          (x.first.to_s.gsub(%r{/+}, '/').freeze)
      end

      def json_body data, raw = false
        content = raw ? data : to_json(server_metadata.merge(data))
        headers = { 'Content-Type' => 'application/json' }
        server_metadata.each do | k, v |
          headers["X-ControlPath-#{k}"] = v.to_s unless v.nil?
        end
        [ 200, headers, [ content.to_s ] ]
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
          path:   path,
          now:    format_time(now),
        }
      end

      def error_response! ct = 'application/json'
        data =
          server_metadata.
          merge(uri: full_uri,
                path: path,
                status: API_ERROR,
                error: "#{response.status}")
        logger.error PP.pp(data.inspect, '')
        content_type ct
        case ct
        when /json/
          body = to_json(data)
          response.body = [ body ]
        else
          erb :error, locals.merge(error: data)
        end
      end

      def full_uri
        query = request.query_string
        query = "?#{query}" unless query.empty?
        "#{request.base_url}#{request.path}#{query}"
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
