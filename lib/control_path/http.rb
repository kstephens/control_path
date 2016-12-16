require 'net/http'
require 'uri'

module ControlPath
  class Http
    def GET uri
      uri = URI.parse(uri) unless URI === uri
      response = nil
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new uri
        response = http.request request
      end
      Response.new(response)
    end

    class Response
      attr_reader :response
      
      def initialize response
        @response = response
      end
      def status
        @response.code.to_i
      end
      def success?
        (200..300).include?(status)
      end
      def body
        @response.body
      end
    end
  end
end
