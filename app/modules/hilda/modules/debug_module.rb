module Hilda::Modules
  class DebugModule
    include Hilda::ModuleBase
    include Hilda::Modules::WithParams

    def initialize(module_graph, param_values={})
      super(module_graph, param_values)
      self.param_defs = self.class.sanitise_field_defs(param_values.fetch(:param_defs,{}))
    end

    def all_params_submitted?
      # Normal WithParams behaviour returns false if nothing is defined.
      return true unless param_defs.try(:any?)
      return super
    end

    def run_module
      sleep(param_values.fetch(:sleep, 0))
      output = param_values.fetch(:module_output, :input)
      if output==:input
        self.module_output = module_input.deep_dup
      else
        self.module_output = output
      end
    end

    def autorun?
      param_values.fetch(:autorun,true)
    end
  end
end
