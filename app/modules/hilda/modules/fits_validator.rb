module Hilda::Modules
  class FitsValidator
    include Hilda::ModuleBase
    include DurhamRails::Actors::ShellRunner
    include DurhamRails::Actors::FitsRunner
    
    attr_accessor :validation_rules

    def initialize(module_graph, param_values={})
      super(module_graph, param_values)
    end
    
    def validation_rules
      self.param_values.fetch(:validation_rules,[])
    end

    def source_files_key
      param_values.fetch(:source_files_key,:source_files).to_sym
    end

    def run_validation_rules(file_label, fits_xml)
      validation_rules.each do |rule|
        unless fits_xml.xpath(rule[:xpath]).any?
          self.run_status = :error
          log! :error, "#{file_label} fails test #{rule[:label]}"
        end
      end
    end
    
    def fits_content_type(fits_xml)
      fits_xml.xpath('/xmlns:fits/xmlns:identification/xmlns:identity/@mimetype').to_s
    end
        
    def validate_files(files)
      test_list = validation_rules.each.map do |r| r[:label] end .join(', ')
      log! :info, "Running Fits tests: #{test_list}"
      files.each do |key,file|
        module_graph.file_service.get_file(file[:path]) do |open_file|        
          (fits_xml, error_out, exit_code) = run_fits_io(open_file)
          unless exit_code == 0
            self.run_status = :error
            log! :error, "Unable to run Fits. #{error_out}"
            break
          end
          file_label = file[:original_filename] || key
          run_validation_rules(file_label, fits_xml)
          file[:content_type] ||= fits_content_type(fits_xml)
        end
      end
      unless self.run_status == :error
        log! :info, "All files passed all Fits tests"
        return true
      else
        log! :info, "Finished running Fits tests"
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
