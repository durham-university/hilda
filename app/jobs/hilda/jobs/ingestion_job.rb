module Hilda::Jobs
  class IngestionJob
    include DurhamRails::Jobs::JobBase
    include DurhamRails::Jobs::WithResource
    include DurhamRails::Jobs::WithUser
    include Hilda::Jobs::HildaJob

    attr_accessor :module_name
    attr_accessor :run_mode

    def initialize(params={})
      super(params)
      self.module_name = params[:module_name]
      self.module_name = module_name.module_name if module_name.is_a? Hilda::ModuleBase
      self.run_mode = params.fetch(:run_mode, self.module_name.present? ? :restart : :continue)
    end

    alias graph resource

    def run_job
      if module_name
        mod = graph.find_module(module_name)
        raise "Couldn't find module \"#{module_name}\"" unless mod
        graph.continue_execution(mod)
      else
        if run_mode == :continue
          graph.continue_execution
        else
          graph.start_graph
        end
      end
    end

    def dump_attributes
      super + [:module_name,:run_mode]
    end
  end
end
