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
        raise 'file path not in temp file index' unless self.param_values[:received_temp_files].index(file_path)
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

    def file_basename(file)
      return File.basename(file) if file.is_a?(String) || file.is_a?(File)
      return file.original_filename if file.respond_to?(:original_filename)
      return nil
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

      unless temp_dir && File.exists?(temp_dir)
        temp_dir = make_temp_file_path
        Dir.mkdir(temp_dir)
        add_temp_file(temp_dir, temp_files)
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
        if basename
          file_path = File.join(temp_dir,sanitise_filename(basename))
          file_path = make_temp_file_path(temp_dir) if File.exists?(file_path)
        else
          file_path = make_temp_file_path(temp_dir)
        end
        raise 'Temporary file already exists' if File.exists?(file_path)

        out = File.open(file_path,'wb')
        IO.copy_stream(file, out)
        out.close
        add_temp_file(file_path, temp_files)

        new_file = {path: file_path, original_filename: basename}.merge(file_hash.except(:file))
        file_values[file_key(file_values,basename)] = new_file
        new_files << new_file
      end
      return new_files
    end

    def calculate_md5(file)
      Digest::MD5.file(file).hexdigest
    end

    def verify_md5s(files)
      errors = false
      files.each do |key,file|
        if file[:md5].present?
          md5 = calculate_md5(file[:path])
          unless md5 == file[:md5]
            log! :error, "MD5 mismatch for #{file[:original_filename]}!"
            errors = true
          end
        else
          log! :warn, "No MD5 received for #{file[:original_filename]}. Adding one now."
          file[:md5] = calculate_md5(file[:path])
        end
      end
      log! :info, "All MD5s match" unless errors
      return errors
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
          files[key] = { path: dest, original_filename: File.basename(entry.name), md5: calculate_md5(dest) }
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
