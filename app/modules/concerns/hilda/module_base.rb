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
      self.module_name = param_values.fetch(:module_name, default_module_name).gsub(/\s/,'_')
      self.param_values = param_values
      self.run_status = :initialized
      self.run_status = :disabled if optional? && self.param_values.fetch(:default_disabled, false)
      self.log = DurhamRails::Log.new
      @load_change_time = 0
      changed!
    end
    
    def optional?
      self.param_values.fetch(:optional_module,false)
    end
    
    def disabled?
      self.run_status == :disabled
    end
    
    def set_disabled(val)
      if val
        raise 'Cannot disable a non-optional module' unless optional?
        return if self.run_status == :disabled
        self.run_status = :disabled
        changed!
      else
        return unless self.run_status == :disabled
        # Just need to set some other state than :disabled or :initialized for
        # reset_module to do the right thing. It'll then set run_status to something
        # more appropriate.
        self.run_status = :error 
        self.reset_module
        # reset_module calls changed!
      end
    end
    
    def disable!
      set_disabled(true)
    end
    def enable!
      set_disabled(false)
    end

    def rendering_option(key,default=nil)
      self.param_values[:rendering_options].try(:[],key.to_sym) || default
    end
    def set_rendering_option(key,value)
      self.param_values[:rendering_options] ||= {}
      self.param_values[:rendering_options][key.to_sym] = value
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

    def query_module(params)
      return { status: 'ERROR', error_message: "Module doesn't support querying" }
    end

    def can_receive_params?
      return respond_to?(:receive_params) && run_status!=:running &&
              run_status!=:finished && module_graph.run_status!=:running
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
      self.log = DurhamRails::Log.from_json(json[:log])
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
      was = self.run_status
      self.run_status = :initialized unless disabled?
      self.module_output = nil
      clear_log
      check_submitted_status! if !disabled? && was!=:initialized && self.respond_to?(:check_submitted_status!)
      changed!
      return true
    end

    def cleanup
      return true if disabled?
      self.run_status = :cleaned
      changed!
      return true
    end

    def rollback
      return cleanup && reset_module
    end

    def autorun?
      self.run_status==:submitted
    end

    def ready_to_run?
      return false unless [:initialized, :queued, :submitted, :error].include?(self.run_status)
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
        self.log! :info, "Executing module"

        if self.ready_to_run?
          self.run_status = :running
          changed!

          self.module_output = {}
          self.module_graph.module_starting(self)
          run_module

          self.log! :info, "Module execution finished"
          self.run_status = :finished unless self.run_status != :running
        else
          self.log! :error, "Module is not ready to run"
          self.run_status = :error
        end

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
    
    def graph_params_changed
    end

  end
end
