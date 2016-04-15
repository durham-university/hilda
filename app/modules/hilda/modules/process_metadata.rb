module Hilda::Modules
  class ProcessMetadata
    include Hilda::ModuleBase
    include Hilda::Modules::WithParams
    
    def initialize(module_graph, param_values={})
      super(module_graph, param_values)
      self.param_defs = self.class.sanitise_field_defs(param_values.fetch(:param_defs,{}))
      check_submitted_status!
    end
    
    def params_output_key
      self.param_values.fetch(:output_key, :process_metadata)
    end    
  end
end