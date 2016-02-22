module Hilda
  module ModuleGraphBehaviour
    extend ActiveSupport::Concern

    attr_accessor :log
    attr_accessor :start_modules
    attr_accessor :graph_params
    attr_accessor :graph

    def initialize(*args)
      self.log = DurhamRails::Log.new
      self.start_modules = []
      self.graph_params = {}
      self.graph = {}
      super(*args)
    end

    def as_json(*args)
      {
        graph_params: graph_params,
        log: log.as_json,
        modules: graph.keys.map(&:as_json),
        graph: graph.each_with_object({}) do |(k,v),o|
          o[k.module_name]=v.map(&:module_name)
        end,
        start_modules: start_modules.map(&:module_name)
      }
    end

    module ClassMethods
      def from_json(json)
        self.allocate.tap do |obj| obj.from_json(json) end
      end
    end
    def from_json(json)
      json = JSON.parse(json) if json.is_a? String
      json = json.with_indifferent_access unless json.is_a? ActiveSupport::HashWithIndifferentAccess
      self.log = DurhamRails::Log.from_json json[:log]
      self.graph_params = json[:graph_params]
      module_index = json[:modules].each_with_object({}) do |mod,o|
        parsed = Hilda::ModuleBase.module_from_json(mod)
        parsed.module_graph = self
        o[parsed.module_name]=parsed
      end
      self.graph = json[:graph].each_with_object({}) do |(k,v),o|
        o[module_index[k]] = v.map do |n| module_index[n] end
      end
      self.start_modules = json[:start_modules].map do |n| module_index[n] end
    end

    def marshal_dump
      as_json
    end
    def marshal_load(json)
      from_json(json)
    end

    delegate :log!, to: :log
    delegate :[], :[]=, :fetch, to: :graph_params

    def graph_params_changed
      graph.keys.each do |mod|
        mod.graph_params_changed
      end      
    end

    def module_sources(mod)
      graph.each_with_object([]) do |(m,next_modules),ret|
        ret << m if next_modules.include?(mod)
      end
    end

    def module_source(mod)
      graph.each do |m,next_modules|
        return m if next_modules.include?(mod)
      end
      return nil
    end

    def find_module(module_name_or_class)
      (graph.keys.find do |m| m.module_name == module_name_or_class end) ||
        (graph.keys.find do |m| m.class == module_name_or_class end )
    end

    def input_for(mod)
      mod = find_module(mod) if mod.is_a?(String) || mod.is_a?(Class)
      return {} if start_modules.include?(mod)
      source_module = module_source(mod)
      raise 'No source module' unless source_module
      raise 'Source module not finished' unless source_module.run_status==:finished
      return source_module.module_output
    end

    def add_start_module(module_class,params={})
      mod = module_class.new(self, params)
      graph[mod] = []
      start_modules << mod
      mod
    end

    def add_module(module_or_class,after_module=nil,params={})
      after_mod = after_module
      after_mod = find_module(after_mod) if after_mod.is_a?(String) || after_mod.is_a?(Class)
      raise "Module '#{after_module}' not found" unless after_mod
      if module_or_class.is_a?(Class)
        mod = module_or_class.new(self, params)
      else
        mod = module_or_class
      end
      graph[mod] ||= []
      graph[after_mod] << mod
      mod
    end

    def changed?(since)
      since < change_time
    end

    def change_time
      graph.keys.map(&:change_time).max || 0
    end

    def run_status(modules=nil)
      modules ||= graph.keys
      return :running     if modules.any? do |mod| mod.run_status == :running end
      return :queued      if modules.any? do |mod| mod.run_status == :queued end
      return :finished    if modules.all? do |mod| mod.run_status == :finished end
      return :submitted   if modules.all? do |mod| mod.run_status == :submitted end
      return :initialized if modules.all? do |mod| mod.run_status == :initialized || mod.run_status == :submitted end
      return :error       if modules.any? do |mod| mod.run_status == :error end
      return :cleaned     if modules.all? do |mod| mod.run_status == :cleaned end
      return :paused
    end

    def reset_graph
      graph.keys.each do |mod| mod.reset_module end
    end

    def reset_module_cascading(from,done=[])
      from = Array(from)
      from.each do |mod|
        if mod.run_status==:finished || mod.run_status==:error
          reset_module_cascading(graph[mod],done)
          mod.reset_module
          done << mod
        end
      end
      done
    end

    def rollback_graph(from=nil)
      from ||= start_modules
      from.each do |mod|
        rollback_graph(graph[mod]) if mod.run_status==:finished
        mod.rollback
      end
    end

    def start_graph
      log! "Starting graph execution"
      reset_graph
      start_modules.each do |mod|
        mod.execute_module()
      end
      graph_stopped
    end

    def finished?
      graph.keys.all? do |mod| mod.run_status==:finished end
    end

    def traverse_modules(from_modules=nil)
      from_modules ||= start_modules
      while !from_modules.empty? do
        from_modules = from_modules.each_with_object([]) do |mod,next_modules|
          if block_given?
            next_modules.concat(graph[mod]) if yield(mod)
          else
            next_modules.concat(graph[mod])
          end
        end
      end
    end

    def ready_modules
      [].tap do |ret|
        traverse_modules do |mod|
          ret << mod if mod.ready_to_run?
          next mod.run_status==:finished
        end
      end
    end

    def continue_execution(modules=nil)
      if modules.nil?
        modules = ready_modules
        log! :warn, "No modules ready to run" if modules.empty?
      end

      modules = Array(modules)

      log! "Continuing graph execution"

      traverse_modules(modules) do |mod|
        mod.reset_module
        next true
      end

      modules.each do |mod|
        mod.execute_module()
      end
      graph_stopped
    end

    def module_finished(mod,execute_next=true)
      graph[mod].each do |next_mod|
        begin
          next_mod.input_changed()
          next_mod.execute_module() if execute_next && next_mod.autorun? && next_mod.ready_to_run?
        rescue StandardError => e
          next_mod.log_module_error(e)
        end
      end
    end

    def module_changed(mod)
    end

    def module_starting(mod)
    end

    def module_error(mod, error)
      log! "Error in module #{mod}", error
    end

    def graph_stopped
      log! "Graph execution stopped"
      graph_finished if finished?
    end

    def graph_finished
      log! "Graph execution finished"
    end

    def cleanup
      raise 'Cannot cleanup graph while it\'s still running' if run_status == :running
      graph.keys.each do |mod|
        mod.cleanup
      end
    end

    def combined_log()
      all_messages = []
      graph.keys.each do |mod|
        next if block_given? && !yield(mod)
        prefix = "#{mod.module_name}: "
        mod.log.to_a.each do |message|
          new_message = DurhamRails::Log::LogMessage.new(message.level,prefix+message.message,message.exception,message.time)
          all_messages << new_message
        end
      end
      all_messages.sort! do |a,b|
        a.time <=> b.time
      end
    end

    def file_service
      @file_service ||= DurhamRails::Services::FileService.new(self)
    end
  end
end
