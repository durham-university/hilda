module Hilda
  module Services
    class FedoraFileService

      class FedoraStreamIO
        def initialize(fedora_file)
          @fedora_file = fedora_file
          @closed = false
          rewind
        end

        def size
          @fedora_file.size
        end

        def length
          size
        end

        def binmode
          # Do nothing.
          # Some code insists on calling binmode on readable objects.
        end

        def read(amount=nil, buf=nil)
          raise IOError, "stream closed" if @closed
          buf ||= ''
          buf.clear
          return buf if amount==0

          if amount.nil?
            buf << consume_buffer
            while chunk = @stream_fiber.resume
              buf << chunk
            end
          else
            buf << consume_buffer(amount)
            return buf if buf.length >= amount
            while chunk = @stream_fiber.resume
              if buf.length + chunk.length >= amount
                d = amount-buf.length
                buf << chunk[0..(d-1)]
                @buffer = chunk[d..-1]
                break
              else
                buf << chunk
              end
            end
          end
          return nil if buf.empty? && amount.present?
          return buf
        end

        def rewind
          raise IOError, "stream closed" if @closed
          @buffer = ''
          @stream_fiber = Fiber.new do
            @fedora_file.stream.each do |chunk|
              Fiber.yield chunk
            end
            Fiber.yield nil
          end
        end

        def close
          @closed = true
        end

        private

          def consume_buffer(count=nil)
            @buffer.slice!(0, count || @buffer.length)
          end
      end

      def initialize(graph)
        @graph = graph
        @file_cache = {}
      end

      def add_file(file_name=nil, in_path=nil, io_or_path=nil, &block)
        raise Hilda::Services::FileService::ArgumentError, 'Given both a file to copy and a block' if io_or_path && block_given?
        raise Hilda::Services::FileService::ArgumentError, 'Given neither a file to copy nor a block' unless io_or_path || block_given?
        file = Hilda::FileServiceFile.new(title: file_name, file_type: Hilda::FileServiceFile::TYPE_FILE, ingestion_process: @graph)
        if in_path
          dir = fetch_file(in_path)
          raise Hilda::Services::FileService::ArgumentError, 'Invalid directory given' unless dir.ingestion_process.id.present? && dir.ingestion_process.id == @graph.id
          raise Hilda::Services::FileService::FileNotFoundError, 'Given path doesn\'t exist' unless dir
          file.directory = dir
        end

        if io_or_path
          file_to_close = nil
          file_to_close = File.open(io_or_path,'rb') if io_or_path.is_a? String
          begin
            file.file_contents.content = (file_to_close || io_or_path).read
          ensure
            file_to_close.close if file_to_close
          end
        else
          file.file_contents.content = StringIO.new
          block.call(file.file_contents.content)
          file.file_contents.content.rewind
        end

        if file.save
          return file.id
        else
          raise Hilda::Services::FileService::FileServiceError, 'Unable to save file'
        end
      end

      def add_dir(file_name=nil, in_path=nil)
        file = Hilda::FileServiceFile.new(title: file_name, file_type: Hilda::FileServiceFile::TYPE_DIRECTORY, ingestion_process: @graph)
        if in_path
          dir = fetch_file(in_path)
          raise Hilda::Services::FileService::FileNotFoundError, 'Given path doesn\'t exist' unless dir
          file.directory = dir
        end

        if file.save
          return file.id
        else
          raise Hilda::Services::FileService::FileServiceError, 'Unable to save directory'
        end
      end

      def file_exists?(file)
        obj = fetch_file(file)
        obj.present? && !obj.directory?
      end

      def dir_exists?(dir)
        obj = fetch_file(dir)
        obj.present? && obj.directory?
      end

      def get_file(key)
        file = fetch_file(key)
        raise Hilda::Services::FileService::FileNotFoundError, 'File doesn\'t exist' unless file && !file.directory?
        # io = StringIO.new(file.file_contents.content || '')
        io = FedoraStreamIO.new(file.file_contents)
        if block_given?
          return yield io
        else
          io
        end
      end

      def file_size(key)
        file = fetch_file(key)
        raise Hilda::Services::FileService::FileNotFoundError, 'File doesn\'t exist' unless file && !file.directory?
        file.file_contents.size
      end

      def remove_file(key)
        file = fetch_file(key)
        raise Hilda::Services::FileService::FileNotFoundError, 'File doesn\'t exist' unless file
        file.destroy
        @file_cache[key] = nil
      end

      private

        def fetch_file(id,reload=false)
          return @file_cache[id] if !reload && @file_cache.key?(id)
          begin
            file = Hilda::FileServiceFile.find(id)
            file = nil unless file.ingestion_process.present? && file.ingestion_process.id == @graph.id
            @file_cache[id] = file
          rescue ActiveFedora::ObjectNotFoundError => e
            @file_cache[id] = nil
          end
        end
    end
  end
end
