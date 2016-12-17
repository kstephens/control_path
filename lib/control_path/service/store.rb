require 'control_path/service'
require 'control_path/json'
require 'fileutils'
require 'time'
require 'uuid'
require 'awesome_print'
require 'digest/sha1'

module ControlPath::Service
  class Store
    include ControlPath::Json
    attr_accessor :dir, :file_system, :logger

    def initialize opts
      @logger      = opts[:logger]
      @dir         = opts[:dir] or raise ArgumentError
      @file_system = opts[:file_system] || ::File
    end

    # Interface:
    def read path, name
      read_file("#{dir}/#{path}/#{name}")
    end

    def write! path, name, data
      write_file("#{dir}/#{path}/#{name}", data)
    end

    def delete! path, name
      file_system.unlink("#{dir}/#{path}/#{name}")
    end

    def files_in_parents path, name
      dirs = path_parents(path)
      dirs.map do | path |
        { file: "#{dir}/#{path}/#{name}",
          path: path,
          name: name,
        }
      end.select{|f| file_system.exist?(f[:file])}
    end

    def path_parents path
      paths = [ ]
      while path != '.'
        paths.push path
        path = File.dirname(path)
      end
      paths
    end

    def files_in_children path, name
      rx = %r{\A#{Regexp.quote(dir)}/(.+?)/#{Regexp.quote(name)}\Z}
      Dir["#{dir}/#{path}/**/#{name}"].sort.map do | file |
        if m = rx.match(file)
          { file: file,
            path: m[1],
            name: m[2],
          }
        end
      end.compact
    end

    # Implementation:

    def logger
      @logger ||= ::Logger.new($stderr)
    end

    def read_file file
      from_json(file_system.read(file))
    end

    def write_file file, data
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
