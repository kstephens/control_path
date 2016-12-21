require 'control_path/service'
require 'control_path/json'
require 'fileutils'
require 'time'
require 'uuid'
require 'awesome_print'
require 'digest/sha1'

module ControlPath::Service
  class Store
    class Error < ::StandardError; end

    include ControlPath::Json
    attr_accessor :dir, :file_system, :logger

    def initialize opts
      @logger      = opts[:logger]
      @dir         = opts[:dir] or raise ArgumentError
      @file_system = opts[:file_system] || ::File
    end

    # Interface:
    def read path, name
      validate_path! path
      read_data("#{dir}/#{path}/#{name}")
    end

    def write! path, name, data
      validate_path! path
      write_data("#{dir}/#{path}/#{name}", data)
    end

    def delete! path, name
      validate_path! path
      file_system.unlink("#{dir}/#{path}/#{name}")
    end

    def parents path, name
      dirs = path_parents(path)
      dirs.map do | path |
        { file: "#{dir}#{path}/#{name}",
          path: path,
          name: name,
        }
      end.select{|f| file_system.exist?(f[:file])}
    end

    def path_parents path
      validate_path! path
      paths = [ ]
      while path != '/'
        paths.push path
        path = File.dirname(path)
      end
      paths
    end

    def children path, name
      validate_path! path
      rx = %r{\A#{Regexp.quote(dir)}(.*?)/#{Regexp.quote(name)}\Z}
      Dir["#{dir}#{path}/**/#{name}"].map do | file |
        file.gsub!(%r{//+}, '/')
        if m = rx.match(file)
          { file: file,
            path: m[1],
            name: name,
          }
        end
      end.compact.
        sort_by{|e| e[:path]}
    end

    # Implementation:

    def valid_path? path
      String === path and \
      %r{^/.*?} =~ path and \
      %r{//+} !~ path
    end

    def validate_path! path
      valid_path?(path) or raise Error, "invalid path #{path.inspect}"
    end

    def logger
      @logger ||= ::Logger.new($stderr)
    end

    def read_data file
      from_json(file_system.read(file))
    end

    def write_data file, data
      content = to_json(data)
      begin
        tmp = "#{file}.#{$$}"
        file_system.mkdir_p(File.dirname(tmp))
        file_system.write(tmp, content)
        file_system.chmod(0644, tmp)
        file_system.rename(tmp, file)
      ensure
        file_system.unlink(tmp) rescue nil
      end
    end

  end
end

class File
  def self.mkdir_p *args
    FileUtils.mkdir_p *args
  end
end
