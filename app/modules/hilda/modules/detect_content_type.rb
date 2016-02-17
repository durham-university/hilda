module Hilda::Modules
  class DetectContentType
    include Hilda::ModuleBase
    
    attr_accessor :allow_only

    def initialize(module_graph, param_values={})
      super(module_graph, param_values)
    end
    
    def allow_only
      self.param_values.fetch(:allow_only,[])
    end

    def use_magic?
      param_values.fetch(:use_magic,true)
    end

    def source_files_key
      param_values.fetch(:source_files_key,:source_files).to_sym
    end

    def source_files
      module_input[source_files_key]
    end

    def split_filename(filename)
      ind = filename.rindex('.')
      if ind
        [filename[0..(ind-1)],filename[ind..-1]]
      else
        [filename,'']
      end
    end

    def detect_content_type(file)
      if use_magic?
        module_graph.file_service.get_file(file[:path]) do |open_file|
          if open_file.respond_to? :seek
            MimeMagic.by_magic(open_file)
          else
            temp = Tempfile.new(split_filename(file[:original_filename]))
            begin
              IO.copy_stream(open_file,temp)
              temp.rewind
              MimeMagic.by_magic(temp)
            ensure
              temp.close(true) # true unlinks the file
            end
          end
        end
      else
        MimeMagic.by_path(file[:original_filename])
      end
    end

    def get_content_types(files)
      files.each_with_object({}) do |(key,file),out|
        out[key] = detect_content_type(file).type
        log! :info, "Set content type \"#{out[key]}\" for #{file[:original_filename]}"
      end
    end

    def merge_output(content_types)
      content_types.each_with_object(module_input.deep_dup) do |(key,type),out|
        out[source_files_key][key].merge!(content_type: type)
      end
    end

    def ensure_allowed_mime_types
      return true unless allow_only.any?
      pass = true
      self.module_output[source_files_key].each do |key,file|
        unless allow_only.include?(file[:content_type])
          log! :error, "Invalid content type #{file[:content_type]} for #{file[:original_filename]}"
          log! :info, "Allowed content types are #{allow_only.join(', ')}"
          pass = false
        end
      end
      pass
    end

    def run_module
      self.module_output = merge_output(get_content_types(source_files))
      self.run_status = :error unless ensure_allowed_mime_types 
    end

    def autorun?
      true
    end
  end
end
