module Hilda
  module ModuleBase
    extend ActiveSupport::Concern

    attr_accessor :module_name
    attr_accessor :log
    attr_accessor :param_values
    attr_accessor :module_output
    attr_accessor :module_graph
    attr_accessor :run_status
    attr_accessor :change_time

    def initialize(module_graph, param_values={})
      self.module_graph = module_graph
      self.module_name = param_values.fetch(:module_name, default_module_name)
      self.param_values = param_values
      self.run_status = :initialized
      self.log = Hilda::Log.new
      @load_change_time = 0
      changed!
    end

    def default_module_name
      base_name = self.class.to_s.underscore.gsub(/[^a-zA-Z0-9_.-]/,'_')
      return base_name unless module_graph.find_module(base_name)
      counter = 1
      begin
        counter += 1
        name = "#{base_name}_#{counter}"
      end while module_graph.find_module(name)
      return name
    end

    def add_module(module_class,after_module=nil,params={})
      if after_module.is_a?(Hash) && params.empty?
        params=after_module
        after_module = nil
      end
      after_module ||= self
      return module_graph.add_module(module_class,after_module,params)
    end
    delegate :add_start_module, to: :module_graph

    def changed!
      was = self.change_time
      self.change_time = (DateTime.now.to_f*1000).to_i
      self.change_time = was+1 if was.present? && self.change_time <= was # in case changed! is called very frequently
      module_graph.module_changed(self)
    end

    def changed?(since=nil)
      since ||= @load_change_time
      return since < change_time
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

      json.slice(:module_name,:param_values,:module_output,:change_time).each do |k,v|
        self.send(:"#{k}=",v)
      end
      self.run_status = json[:run_status].to_sym
      self.log = Hilda::Log.from_json(json[:log])
      @load_change_time = self.change_time
      yield json if block_given?
    end

    def as_json(*args)
      [:module_name,:param_values,:module_output,:run_status,:change_time].each_with_object({
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
       module_graph.input_for(self)
    end

    def clear_log
      self.log.clear!
      changed!
      return true
    end

    def reset_module
      self.run_status = :initialized
      self.module_output = nil
      clear_log
      changed!
      return true
    end

    def cleanup
      self.run_status = :cleaned
      changed!
      return true
    end

    def rollback
      return cleanup && reset_module
    end

    def autorun?
      false
    end

    def ready_to_run?
      return false unless self.run_status==:initialized || self.run_status==:error
      source = module_graph.module_source(self)
      return false unless source.nil? || source.run_status==:finished
      return true
    end

    def log_module_error(e)
      self.run_status = :error
      log! e
      changed!
      self.module_graph.module_error(self, e)
    end

    def execute_module()
      begin
        self.run_status = :running
        changed!

        self.module_output = {}
        self.module_graph.module_starting(self)
        run_module

        self.run_status = :finished unless self.run_status != :running
        changed!
        self.module_graph.module_finished(self) if self.run_status == :finished
      rescue StandardError => e
        log_module_error(e)
      end
    end

    def run_module
      raise 'run_module not implemented in module'
    end

    def input_changed
    end

  end
end
