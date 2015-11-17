module Hilda::Modules
  class FileReceiver
    include Hilda::ModuleBase
    include Hilda::Modules::WithTempFiles
    include Hilda::Modules::WithParams

    def initialize(*args)
      super(*args)
      self.param_defs = { files: { name: 'files', type: :file, default: nil } }
      self.param_values.merge!({form_template: 'hilda/modules/file_upload'})
      set_rendering_option(:no_submit,true)
    end

    def receive_params(params)
      raise "Module cannot receive params in current state" unless can_receive_params?
      if params.key?(:files)
        files = params_array(params[:files])
        md5s = params_array(params[:md5s])
        add_received_files( files.zip(md5s).map do |x| {file: x[0], md5: x[1]} end )
        changed!
      end
      if params.key?(:remove_file)
        remove_received_file(params[:remove_file])
        changed!
      end
      if params.key?(:remove_all_files)
        remove_received_temp_files
        self.param_values.merge!({
            files: {},
            received_temp_files: []
          })
        changed!
      end
      return true
    end

    def add_received_files(files_and_md5s)
      make_copies_of_files(files_and_md5s)
    end

    def remove_received_file(file_key)
      received_files = self.param_values[:files] || {}
      if received_files.key?(file_key)
        file_path = received_files[file_key][:path]
        raise 'file not in temp file index' unless self.param_values[:received_temp_files].index(file_path)
        remove_temp_files([file_path])
        self.param_values[:received_temp_files].delete(file_path)
        received_files.delete(file_key)
      end
    end

    def remove_all_received_files
      remove_received_temp_files
      self.param_values.merge!({
          files: {},
          received_temp_files: []
        })
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

    def file_key(hash,basename)
      basename ||= 'unnamed_file'
      key = basename
      counter = 1
      while(hash.key?(key)) do
        counter += 1
        key = "#{basename}_#{counter}"
      end
      key
    end

    def make_copies_of_files(files)
      self.param_values ||= {}
      self.param_values[:files] ||= {}
      self.param_values[:received_temp_files] ||= []
      # param_values has indifferent access and this won't work files = (self.param_values[:files] ||= {})
      file_values = self.param_values[:files]
      temp_files = self.param_values[:received_temp_files]
      temp_dir = self.param_values[:temp_dir]

      unless temp_dir && module_graph.file_service.dir_exists?(temp_dir)
        temp_dir = add_temp_dir(nil,temp_files,nil)
        self.param_values[:temp_dir] = temp_dir
      end

      new_files = []
      files.each do |file_hash|
        if file_hash.is_a? File
          file = file_hash
          file_hash = { file: file }
        else
          file = file_hash[:file]
        end

        basename = file_basename(file)
        file_path = add_temp_file(temp_dir, temp_files, file)

        new_file = {path: file_path, original_filename: basename}.merge(file_hash.except(:file))
        file_values[file_key(file_values,basename)] = new_file
        new_files << new_file
      end
      return new_files
    end

    def calculate_md5(readable)
      digest = Digest::MD5.new
      buf = ""
      while readable.read(16384, buf)
        digest.update(buf)
      end
      digest.hexdigest
    end

    def verify_md5s(files)
      errors = false
      files.each do |key,file|
        module_graph.file_service.get_file(file[:path]) do |stored|
          if file[:md5].present?
            md5 = calculate_md5(stored)
            unless md5 == file[:md5]
              log! :error, "MD5 mismatch for #{file[:original_filename]}!"
              errors = true
            end
          else
            log! :warn, "No MD5 received for #{file[:original_filename]}. Adding one now."
            file[:md5] = calculate_md5(stored)
          end
        end
      end
      log! :info, "All MD5s match" unless errors
      return errors
    end

    def unzip(file)
      files = {}
      dir = add_temp_dir

      module_graph.file_service.get_file(file) do |in_file|
        zip_file = Zip::File.new(nil, true, true)
        zip_file.read_from_stream(in_file)

        zip_file.each do |entry|
          next unless entry.file?
          key = file_key(files, File.basename(entry.name))
          path = add_temp_file(dir, nil, File.basename(entry.name)) do |out_file|
            entry.get_input_stream do |in_file|
              IO.copy_stream(in_file, out_file)
            end
          end
          md5 = module_graph.file_service.get_file(path) do |file|
            calculate_md5(file)
          end
          files[key] = { path: path, original_filename: File.basename(entry.name), md5: md5 }
        end
      end

      files
    end

    def unpack_files(files)
      return (files.values.each_with_object({}) do |file,hash|
        if File.extname(file[:original_filename]).downcase == '.zip'
          log! :info, "Unpacking #{file[:original_filename]}"
          unzip(file[:path]).values.each do |unzipped|
            hash[file_key(hash,unzipped[:original_filename])] = unzipped
          end
        else
          hash[file_key(hash,file[:original_filename])] = file
        end
      end)
    end

    def run_module
      unless all_params_valid?
        log! :error, 'Submitted values are not valid, cannot proceed.'
        self.run_status = :error
        return
      end

      files = param_values[:files]
      log! :info, "Received #{files.length} files"
      if verify_md5s(files)
        self.run_status = :error
        return
      end
      files = unpack_files(files) if module_graph.fetch(:unpack_files, true)
      module_output.merge!({ source_files: files })
    end

    private

      def params_array(params)
        if params.is_a? Hash
          params.each_with_object([]) do |(key,value),obj| obj << [key,value] end \
              .sort do |a,b| a[0].to_i <=> b[0].to_i end \
              .map do |a| a[1] end
        elsif params.is_a? Array
          # Do not use just Array(params), it causes problems with files
          params
        else
          [params]
        end
      end

  end
end
