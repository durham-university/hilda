module Hilda::Modules
  module WithJobTag
    extend ActiveSupport::Concern

    attr_accessor :job_tag
    
    def assign_job_tag
      self.job_tag ||= [(module_graph.try(:id) || SecureRandom.hex), (module_name || SecureRandom.hex)].join('/')
    end
    
    def execute_module
      # Set job tag here so that it definitely gets set and saved before running.
      # Can't set in initialize because of how it behaves with graph templates and json initialisation.
      assign_job_tag
      super
    end

    def from_json(json)
      super(json) do |json|
        self.job_tag = json[:job_tag]
        yield(json) if block_given?
      end
    end

    def as_json(*args)
      super(*args).tap do |json|
        json[:job_tag] = job_tag
      end
    end

  end
end