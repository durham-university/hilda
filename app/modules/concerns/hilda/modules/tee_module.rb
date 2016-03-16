module Hilda::Modules
  module TeeModule
    extend ActiveSupport::Concern
    
    def initialize(module_graph, param_values={})
      super(module_graph, param_values)
      raise 'Tee module should not be disabled' if param_values[:optional_module?]
      @connectors = {}
    end
    
    def set_connector_name(mod,name)
      mod = mod.module_name if mod.is_a?(Hilda::ModuleBase)
      @connectors[mod] = name.to_s
    end
    
    def connector_name(mod)
      mod = mod.module_name if mod.is_a?(Hilda::ModuleBase)
      @connectors[mod]
    end
    
    def module_sources
      module_graph.module_sources(self).each_with_object({}) do |source,ret|
        ret[connector_name(source) || (ret.count)] = source
      end
    end
    
    def module_input
      module_sources.each_with_object({}) do |(key, source),ret|
        return nil unless source.run_status==:finished
        ret[key] = source.module_output
      end
    end
    
    def have_all_inputs?
      module_sources.each do |key, source|
        return false unless source.run_status==:finished
      end      
      return true
    end
    
    def ready_to_run?
      super && have_all_inputs?
    end
    
    def as_json(*args)
      super(*args).tap do |json|
        json[:connectors] = @connectors
      end
    end    
    
    def rollback
      # TODO: This will probably need some special handling
      raise "Not implemented"
    end
    
  end
end
