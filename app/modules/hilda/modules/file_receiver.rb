module Hilda::Modules
  class FileReceiver
    include Hilda::ModuleBase
    include Hilda::Modules::WithTempFiles
    include Hilda::Modules::WithParams

    def initialize(*args)
      super(*args)
      self.param_defs = { file: { name: 'file', type: :file, default: nil } }
    end

    def receive_params(params)
      raise 'No file received' unless params.key?(:file)

      remove_received_temp_files
      received_temp_files = []
      self.param_values = {
        received_files: make_copies_of_files( [params[:file]],received_temp_files),
        copy_files: false,
        received_temp_files: received_temp_files
      }

      # this is just feedback for user that the file was received.
      self.param_values[:file] = "#{params[:file].original_filename} (#{params[:file].size} bytes)"

      changed!
      return true
    end

    def remove_received_temp_files
      if self.param_values.fetch(:received_temp_files,[]).any?
        remove_temp_files(self.param_values[:received_temp_files])
        self.param_values[:received_temp_files]=[]
      end
    end

    def cleanup(*args)
      remove_received_temp_files
      return super(*args)
    end

    def file_basename(file)
      return File.basename(file) if file.is_a?(String) || file.is_a?(File)
      return file.original_filename if file.respond_to?(:original_filename)
      return nil
    end

    def file_key(hash,basename)
      key = basename
      counter = 1
      while(hash.key?(key)) do
        counter += 1
        key = "#{basename}_#{counter}"
      end
      key
    end

    def make_copies_of_files(files, temp_file_index=nil )
      dir = make_temp_file_path
      Dir.mkdir(dir)
      add_temp_file(dir, temp_file_index)

      return files.each_with_object({}) do |file,hash|
        basename = file_basename(file)
        if basename
          file_path = File.join(dir,sanitise_filename(basename))
        else
          file_path = make_temp_file_path(dir)
        end
        raise 'Temporary file already exists' if File.exists?(file_path)

        out = File.open(file_path,'wb')
        IO.copy_stream(file, out)
        out.close
        add_temp_file(file_path,temp_file_index)

        hash[file_key(hash,basename)] = {path: file_path, original_filename: basename}
      end
    end

    def unzip(file)
      files = {}
      dir = make_temp_file_path
      Dir.mkdir(dir)
      add_temp_file(dir)

      Zip::File.open(file) do |zip_file|
        zip_file.each do |entry|
          key = file_key(files, File.basename(entry.name))
          dest = File.join(dir, key)
          entry.extract(dest)
          add_temp_file(dest)
          files[key] = { path: dest, original_filename: File.basename(entry.name) }
        end
      end
      files
    end

    def unpack_files(files)
      return (files.values.each_with_object({}) do |file,hash|
        if File.extname(file[:original_filename]).downcase == '.zip'
          unzip(file[:path]).values.each do |unzipped|
            hash[file_key(hash,unzipped[:original_filename])] = unzipped
          end
        else
          hash[file_key(hash,file[:original_filename])] = file
        end
      end)
    end

    def ready_to_run?
      return false unless super
      return false unless got_all_param_values?
      return true
    end

    def run_module
      files = param_values[:received_files]
      files = make_copies_of_files(files) if param_values.fetch(:copy_files, true)
      files = unpack_files(files) if module_graph.fetch(:unpack_files, true)
      module_output.merge!({ source_files: files })
    end

  end
end
