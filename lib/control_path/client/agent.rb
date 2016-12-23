require 'control_path/http'
require 'control_path/json'
require 'control_path/random'
require 'logger'

module ControlPath::Client
  class Agent
    include ControlPath::Json, ControlPath::Random

    attr_accessor :uri, :interval, :config, :verbose
    attr_accessor :http
    attr_accessor :on_change

    attr_accessor :state, :action
    attr_accessor :response, :response_prev
    attr_accessor :new_data, :prev_data, :data
    attr_accessor :prev_interval
    attr_accessor :host, :agent_id

    def initialize opts = nil, &blk
      @last_intervals = [ ]
      self.host = Socket.gethostname
      self.agent_id = new_version
      opts.each do | k, v |
        self.send(:"#{k}=", v)
      end if opts
      instance_eval &blk if block_given?
      self
    end

    def test!
      self.new_data ||= lambda do | this, data |
        { time: Time.now.to_i }
      end
      self.on_change ||= lambda do | this, response |
        $stderr.puts "#{self.class} on_change #{this.data.inspect}"
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
      check! if state != :stopping && state != :paused
      sleep! if state != :stopping
      self
    end

    def stop!
      self.action = :stop
      self.state  = :stopping
      self
    end

    def pause!
      if state == :running
        self.action = :pause
        self.state  = :paused
      end
      self
    end

    def resume!
      if state == :paused
        self.action = :resume
        self.state  = :running
      end
      self
    end

    def check!
      uri = uri_for config

      query = { }
      if response_prev and x = response_prev.body_data and x = x[:control]
        query[:version] = x[:version]
      end
      query[:host] = host
      query[:agent_id] = agent_id
      query[:interval] = max_interval(interval)
      uri.query = query.map{|k, v| "#{k}=#{v}"} * '&'

      begin
        if data = new_data && new_data.call(self, prev_data)
          http.PUT(uri, to_json(data)) do | response |
            handle_response! response
          end
          self.prev_data = data
        else
          http.GET(uri) do | response |
            handle_response! response
          end
        end
      rescue => exc
        log_exception! exc
      end
    end

    def handle_response! response
      if response.success?
        self.response_prev = self.response
        self.response      = response
        if changed?(response, response_prev)
          if response.body && ! response.body.empty?
            self.data = from_json(response.body)
          end
          changed! response
        end
      end
    end

    def log_exception! exc
      logger.error "#{uri} failed: #{exc.inspect}"
      logger.error "  #{exc.backtrace * "\n  "}" if verbose
    end

    def changed? a, b
      a && a.success? && \
      b && b.success? && \
      a.body != b.body
    end

    def changed! response
      logger.info "changed! #{response.uri}"
      on_change.call(self, response)
    end

    def uri_for config = self.config
      URI.parse(expand_template(uri, config))
    end

    def sleep!
      sec = rand(interval)
      self.prev_interval = sec
      @last_intervals.shift while @last_intervals.size > 10
      @last_intervals.push sec
      sleep(sec)
      self
    end

    def expand_template template, data
      template.to_s.gsub(/#\{\s*([^\s\}]+)\s*}/) do | m |
        k = $1.to_sym
        data[k]
      end
    end

    def max_interval interval
      case interval
      when Proc
        @last_intervals.max
      when Range
        interval.last
      when Numeric
        interval
      end
    end

    def logger
      @logger ||= ::Logger.new($stderr)
    end
  end
end
