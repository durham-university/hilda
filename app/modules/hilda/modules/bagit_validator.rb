module Hilda::Modules
  class BagitValidator
    include Hilda::ModuleBase
    
    def initialize(module_graph, param_values={})
      super(module_graph, param_values)
    end

    def source_files_key
      param_values.fetch(:source_files_key,:source_files).to_sym
    end
    
    def validate_bag(open_file)
      validator = DurhamRails::BagitValidator.new(self.log)
      begin
        validator.read_bagit_zip_io(open_file)
        if self.log.errors?
          self.run_status = :error
        else
          if validator.validate
            log!(:info, "Bagit validated")
            log!(:debug, "Bag payload")
            validator.info.payload.keys.sort.each do |file|
              log!(:debug,"  #{file} md5:#{validator.info.payload[file][:checksums][:md5]}")            
            end
          else
            self.run_status = :error
          end
        end
      rescue StandardError => e
        self.run_status = :error
        log!(:error, e)
      end
    end
        
    def validate_files(files)
      log!(:info, "Validating bags")
      files.each do |key,file|
        module_graph.file_service.get_file(file[:path]) do |open_file|
          log!(:info, "Validating Bagit bag #{file[:original_filename]}")
          validate_bag(open_file)
          break if self.run_status == :error
        end
      end
      unless self.run_status == :error
        log!(:info, "All files passed bags validation")
        return true
      else
        log!(:error, "Error validating bags")
        return false
      end
    end

    def run_module
      self.module_output = module_input.deep_dup
      files = self.module_output[source_files_key]
      self.module_output = nil unless validate_files(files)
    end

    def autorun?
      true
    end
  end
end
