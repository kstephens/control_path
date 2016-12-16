require 'control_path/http'
require 'logger'

module ControlPath::Client
  class Agent
    attr_accessor :uri, :interval, :config
    attr_accessor :http
    attr_accessor :on_change

    attr_accessor :state, :action
    attr_accessor :response, :response_prev

    def initialize opts = nil, &blk
      opts.each do | k, v |
        self.send(:"#{k}=", v)
      end if opts
      instance_eval &blk if block_given?
      self.on_change ||= lambda do | this, response |
        $stderr.puts "#{self.class} on_change"
      end
      self
    end

    def run!
      self.state = :starting
      while action != :stop
        self.state = :running
        step!
      end
      self.state = :stopped
      self
    end

    def step!
      check! if state != :stopping
      sleep! if state != :stopping
      self
    end

    def stop!
      self.action = :stop
      self.state  = :stopping
      self
    end

    def check!
      uri = uri_for config
      begin
        http.GET(uri) do | response |
          if response.success?
            self.response_prev = self.response
            self.response      = response
            if changed?(response, response_prev)
              changed! response
            end
          end
        end
      rescue => exc
        logger.error "#{uri} failed: #{exc.inspect}"
      end
    end

    def changed? repsonse, response_prev
      response && response.success? &&
        response_prev && response_prev.success? &&
        response.body != response_prev.body
    end

    def changed! response
      logger.info "changed! #{response.uri}"
      on_change[self, response]
    end

    def uri_for config = self.config
      expand_template(uri, config)
    end

    def sleep!
      sleep rand(interval)
      self
    end

    def expand_template template, data
      template.to_s.gsub(/#\{\s*([^\s\}]+)\s*}/) do | m |
        k = $1.to_sym
        data[k]
      end
    end

    def rand interval
      case interval
      when Proc
        interval[]
      when Range
        t = rand_float
        interval.first * (1.0 - t) + interval.last * t
      when Numeric
        interval.to_f
      end
    end

    def rand_float
      Kernel.rand
    end

    def logger
      @logger ||= ::Logger.new($stderr)
    end
  end
end
