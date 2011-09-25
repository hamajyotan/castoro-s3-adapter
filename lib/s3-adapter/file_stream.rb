
module S3Adapter
  class FileStream
    def initialize path, options = {}
      @path  = path
      @stat  = File.stat(path)
      @pos   = options[:pos]
      @bytes = options[:bytes]
      @range = (@pos || 0)..(@bytes ? [@bytes, @stat.size-1].min : @stat.size-1)
    end

    def headers
      {}.tap { |h|
        h['content-range'] = "bytes #{@range.begin}-#{@range.end}/#{@stat.size}" if @pos or @bytes
      }
    end

    def status
      (@pos || @bytes) ? 206 : 200
    end

    def each
      File.open(@path, 'rb') { |f|
        f.seek @range.begin
        remaining_len = @range.end-@range.begin+1
        while remaining_len > 0
          part = f.read([8192, remaining_len].min)
          break unless part
          remaining_len -= part.length

          yield part
        end
      }
    end
  end
end

