module Hilda
  module ModuleBase
    extend ActiveSupport::Concern

    attr_accessor :module_name
    attr_accessor :log
    attr_accessor :param_values
    attr_accessor :param_defs
    attr_accessor :module_output
    attr_accessor :module_graph
    attr_accessor :run_status

    def initialize(module_name, module_graph, param_values={})
      self.module_name = module_name
      self.module_graph = module_graph
      self.param_values = param_values
      self.run_status = :initialized
      self.log = Hilda::Log.new
    end

    def self.module_from_json(json)
      json = JSON.parse(json) if json.is_a? String
      json = json.with_indifferent_access unless json.is_a? ActiveSupport::HashWithIndifferentAccess
      json[:class].constantize.from_json(json)
    end

    module ClassMethods
      def from_json(json)
        self.allocate.tap do |obj| obj.from_json(json) end
      end
    end

    def from_json(json)
      json = JSON.parse(json) if json.is_a? String
      json = json.with_indifferent_access unless json.is_a? ActiveSupport::HashWithIndifferentAccess

      json.slice(:module_name,:param_values,:param_defs,:module_output).each do |k,v|
        self.send(:"#{k}=",v)
      end
      self.run_status = json[:run_status].to_sym
      self.log = Hilda::Log.from_json(json[:log])
    end

    def as_json(*args)
      [:module_name,:param_values,:param_defs,:module_output,:run_status].each_with_object({
          class: self.class.to_s,
          log: log.as_json
        }) do |attribute,o|
        o[attribute]=self.send(attribute)
      end
    end

    def marshal_dump
      as_json
    end

    def marshal_load(hash)
      from_json(hash)
    end


    delegate :log!, to: :log

    def module_input
       @module_input ||= module_graph.input_for(self)
    end

    def reset_module
      self.run_status = :initialized
      self.module_output = nil
    end

    def cleanup
      self.run_status = :cleaned
    end

    def rollback
      cleanup
      reset_module
    end

    def autorun?
      false
    end

    def execute_module()
      begin
        self.run_status = :running

        self.module_output = {}
        run_module

        self.run_status = :finished
        self.module_graph.module_finished(self)
      rescue => e
        self.run_status = :error
        log! e
        self.module_graph.module_error(self, e)
      end
    end

    def run_module
      raise 'run_module not implemented in module'
    end

  end
end
