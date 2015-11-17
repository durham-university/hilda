module Hilda::Modules
  module WithTempFiles
    extend ActiveSupport::Concern

    def file_basename(file)
      return File.basename(file) if file.is_a?(String) || file.is_a?(File)
      return file.original_filename if file.respond_to?(:original_filename)
      return nil
    end

    def add_temp_file(in_path=nil, index=nil, file=nil, &block)
      unless index
        # param_values has indifferent access and things like a = ( b[:temp_files] ||= [])
        # don't work as you might expect
        param_values[:temp_files] ||= []
        index = param_values[:temp_files]
      end
      module_graph.file_service.add_file(file_basename(file), in_path, block_given? ? nil : file, &block).tap do |key|
        index << key
      end
    end

    def add_temp_dir(in_path=nil, index=nil, dir=nil)
      unless index
        # param_values has indifferent access and things like a = ( b[:temp_files] ||= [])
        # don't work as you might expect
        param_values[:temp_files] ||= []
        index = param_values[:temp_files]
      end
      module_graph.file_service.add_dir(dir, in_path).tap do |key|
        index << key
      end
    end

    def reset_module(*args)
      remove_temp_files
      self.param_values.try(:[]=,:temp_files,[])
      return super(*args)
    end

    def cleanup(*args)
      remove_temp_files
      return super(*args)
    end

    def remove_temp_files(files=nil)
      files ||= self.param_values.try(:[],:temp_files) || []
      file_service = module_graph.file_service
      # Go in reverse order so that directories are removed after contents
      files.reverse.each do |file|
        module_graph.file_service.remove_file(file) if file_service.file_exists?(file) || file_service.dir_exists?(file)
      end
    end

  end
end
