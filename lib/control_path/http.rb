require 'net/http'
require 'uri'
require 'control_path/json'

module ControlPath
  class Http
    def GET uri
      uri = URI.parse(uri) unless URI === uri
      response = nil
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new uri
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
