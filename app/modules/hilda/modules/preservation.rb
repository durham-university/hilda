module Hilda::Modules
  class Preservation
    include Hilda::ModuleBase

    def preserve_files(input_files)
      # Dummy implementation
      input_files.each_with_object({}) do |file,o|
        o[file] = "http://www.example.com/#{file}"
      end
    end

    def run_module
      preserved_files = preserve_files(module_input[:source_files])
      self.module_output = module_input.deep_dup.merge({
        preserved_files: preserved_files
      })
    end

    def autorun?
      true
    end
  end
end
