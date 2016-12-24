require 'net/http'
require 'uri'
require 'control_path/json'

module ControlPath
  class Http
    def GET uri, &blk
      GO uri, nil , Net::HTTP::Get, &blk
    end

    def PUT uri, body, &blk
      GO uri, body, Net::HTTP::Put, &blk
    end

    def PATCH uri, body, &blk
      GO uri, body, Net::HTTP::Patch, &blk
    end

    def GO uri, body, rq_cls, &blk
      uri = URI.parse(uri) unless URI === uri
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = rq_cls.new uri
        request.body = body if body
        response = http.request request
        response = Response.new(response, uri)
        yield response
      end
    end

    class Response
      include Json
      attr_reader :response, :at, :uri

      def initialize response, uri
        @response = response
        @at = Time.now.utc
        @uri = uri
      end
      def status
        @response.code.to_i
      end
      def success?
        (200...300).include?(status)
      end
      def body
        @response.body
      end
      def body_data
        @body_data ||= from_json(body)
        rescue
      end
    end
  end
end
