module Hilda
  module Services
    class FileService
      class FileServiceError < StandardError ; end
      class FileNotFoundError < FileServiceError ; end
      class ArgumentError < FileServiceError ; end

      def initialize(graph)
        @graph = graph
      end

      def add_file(file_name=nil, in_path=nil, io_or_path=nil, &block)
        raise ArgumentError, 'Given both a file to copy and a block' if io_or_path && block_given?
        raise ArgumentError, 'Given neither a file to copy nor a block' unless io_or_path || block_given?
        raise ArgumentError, 'Given path is not under temp dir' if in_path && !under_temp_dir?(in_path)
        raise FileNotFoundError, 'Given path doesn\'t exist' if in_path && !File.exists?(in_path)
        raise FileNotFoundError, 'Given path is not a directory' if in_path && !File.directory?(in_path)
        out_path = make_temp_file_path(in_path, file_name)

        if io_or_path
          file_to_close = nil
          file_to_close = File.open(io_or_path,'rb') if io_or_path.is_a? String
          begin
            File.open(out_path,'wb') do |out_file|
              IO.copy_stream(file_to_close || io_or_path, out_file)
            end
          ensure
            file_to_close.close if file_to_close
          end
        else
          File.open(out_path,'wb',&block)
        end

        out_path
      end

      def add_dir(file_name=nil, in_path=nil)
        raise ArgumentError, 'Given path is not under temp dir' if in_path && !under_temp_dir?(in_path)
        raise FileNotFoundError, 'Given path doesn\'t exist' if in_path && !File.exists?(in_path)
        raise FileNotFoundError, 'Given path is not a directory' if in_path && !File.directory?(in_path)
        dir_path = make_temp_file_path(in_path, file_name)
        Dir.mkdir(dir_path)
        dir_path
      end

      def file_exists?(file)
        raise ArgumentError, 'Given path is not under temp dir' unless under_temp_dir?(file)
        File.exists?(file) && !File.directory?(file)
      end

      def dir_exists?(dir)
        raise ArgumentError, 'Given path is not under temp dir' unless under_temp_dir?(dir)
        File.exists?(dir) && File.directory?(dir)
      end

      def get_file(key)
        raise ArgumentError, 'Given path is not under temp dir' unless under_temp_dir?(key)
        raise FileNotFoundError, 'File doesn\'t exist' if !File.exists?(key) || File.directory?(key)
        file = File.open(key,'rb')
        if block_given?
          begin
            return yield file
          ensure
            file.close
          end
        else
          file
        end
      end

      def file_size(key)
        raise ArgumentError, 'Given path is not under temp dir' unless under_temp_dir?(key)
        raise FileNotFoundError, 'File doesn\'t exist' if !File.exists?(key) || File.directory?(key)
        File.size(key)
      end

      def remove_file(key)
        raise ArgumentError, 'Given path is not under temp dir' unless under_temp_dir?(key)
        raise FileNotFoundError, 'File doesn\'t exist' unless File.exists?(key)
        if File.directory?(key)
          Dir.unlink(key)
        else
          File.unlink(key)
        end
      end

      private
        def under_temp_dir?(path)
          tmp = temp_dir
          tmp += File::SEPARATOR unless tmp.ends_with? File::SEPARATOR
          File.absolute_path(path).start_with?(tmp) && path.length > tmp.length
        end

        def temp_dir
          @graph.fetch(:temp_dir,Dir.tmpdir) || raise('Couldn\'t resolve temp dir')
        end

        def make_temp_file_path(dir=nil,file_name=nil)
          dir ||= temp_dir
          file_name = sanitise_filename(file_name) if file_name
          file_name = nil if file_name.blank?
          file_name ||= SecureRandom.hex
          loop do
            path = File.join(dir,file_name)
            break path unless File.exists?(path)
            file_name = SecureRandom.hex
          end
        end

        def sanitise_filename(file_name)
          return '_' if file_name == '.'
          return '__' if file_name == '..'
          file_name.gsub(/[^a-zA-Z0-9_\.-]/,'_')
        end

    end
  end
end
