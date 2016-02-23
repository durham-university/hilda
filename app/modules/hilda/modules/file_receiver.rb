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
      if params.key?(:remove_file)
        remove_received_file(params[:remove_file])
        file_names_changed!
        changed!
      end
      if params.key?(:remove_all_files)
        remove_all_received_files
        file_names_changed!
        changed!
      end
      if params.key?(:file_names)
        set_received_file_names( params_array(params[:file_names]) )
        file_names_changed!
        check_submitted_status!
        changed!
      end
      if params.key?(:files)
        files = params_array(params[:files])
        md5s = params_array(params[:md5s])
        add_received_files( files.zip(md5s).map do |x| {file: x[0], md5: x[1]} end )
        check_submitted_status!
        changed!
      end
      return true
    end

    def all_params_submitted?
      super && all_files_received?
    end
    
    def all_files_received?
      return false unless self.param_values[:file_names].present?
      return false unless self.param_values[:files].present?
      self.param_values[:file_names].select do |file_name|
        return false unless self.param_values[:files][file_name].present?
      end
      return true
    end

    def add_received_files(files)
      self.param_values ||= {}
      self.param_values[:files] ||= {}
      self.param_values[:received_temp_files] ||= []
      # param_values has indifferent access and this won't work files = (self.param_values[:files] ||= {})
      file_values = self.param_values[:files]
      temp_files = self.param_values[:received_temp_files]
      temp_dir = self.param_values[:temp_dir]
      
      # check files before adding anything
      files.each do |file|
        file = file[:file] unless file.is_a? File
        file_name = file_basename(file)
        raise "Sent file name was not pre-defined \"#{file_name}\"" unless self.param_values[:file_names].try(:include?,file_name)
      end      

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
        
        file_name = file_basename(file)

        file_path = add_temp_file(temp_dir, temp_files, file)

        new_file = {path: file_path, original_filename: file_name}.merge(file_hash.except(:file))
        file_values[file_name] = new_file
        new_files << new_file
      end
      return new_files
    end
    
    def set_received_file_names(file_names)
      (self.param_values[:files] || {}).each do |file_name,file|
        unless file_names.include? file_name
          raise "cannot remove pre-configured file name when that file has already been uploaded \"#{file_name}\""
        end
      end
      self.param_values.merge!({file_names: file_names})
    end
    
    def file_names_changed!
      self.module_graph[:source_file_names] = param_values[:file_names]
      self.module_graph.graph_params_changed
    end

    def remove_received_file(file_name)
      received_files = self.param_values[:files] || {}
      file_names = self.param_values[:file_names] || {}
      if received_files.key?(file_name)
        file_path = received_files[file_name][:path]
        raise 'file not in temp file index' unless self.param_values[:received_temp_files].index(file_path)
        remove_temp_files([file_path])
        self.param_values[:received_temp_files].delete(file_path)
        received_files.delete(file_name)
        file_names.delete(file_name)
      end
    end

    def remove_all_received_files
      remove_received_temp_files
      self.param_values.merge!({
          files: {},
          file_names: [],
          received_temp_files: []
        })
      self.module_graph[:source_file_names] = nil
      self.module_graph.graph_params_changed
    end

    def remove_received_temp_files
      if self.param_values.fetch(:received_temp_files,[]).any?
        remove_temp_files(self.param_values[:received_temp_files])
        self.param_values[:received_temp_files]=[]
      end
    end

    def cleanup(*args)
      remove_all_received_files
      return super(*args)
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
      log! :info, "Verifying MD5s"
      errors = false
      files.each do |key,file|
        module_graph.file_service.get_file(file[:path]) do |stored|
          if file[:md5].present?
            md5 = calculate_md5(stored)
            unless md5 == file[:md5]
              log! :error, "MD5 mismatch for #{key} => #{file[:original_filename]}!"
              errors = true
            end
          else
            log! :warn, "No MD5 received for #{key} => #{file[:original_filename]}. Adding one now."
            file[:md5] = calculate_md5(stored)
          end
        end
      end
      log! :info, "All MD5s match" unless errors
      return errors
    end

    def run_module
      unless all_params_valid?
        log! :error, 'Submitted values are not valid, cannot proceed.'
        self.run_status = :error
        return
      end

      files = param_values[:files]
      log! :info, "Received #{files.length} files"
      files.each do |key,file|
        log! :info, "- #{file[:original_filename]} (md5:#{file[:md5]})"
      end
      if verify_md5s(files)
        self.run_status = :error
        return
      end
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
