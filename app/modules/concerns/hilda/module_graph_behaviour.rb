module Hilda
  module ModuleGraphBehaviour
    extend ActiveSupport::Concern

    attr_accessor :log
    attr_accessor :start_modules
    attr_accessor :graph_params
    attr_accessor :graph

    def initialize(*args)
      self.log = Hilda::Log.new
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
      self.log = Hilda::Log.from_json json[:log]
      self.graph_params = json[:graph_params]
      module_index = json[:modules].each_with_object({}) do |mod,o|
        parsed = Hilda::ModuleBase.module_from_json(mod)
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

    def module_source(mod)
      graph.each do |m,next_modules|
        return m if next_modules.include?(mod)
      end
      return nil
    end

    def find_module(module_name)
      graph.keys.find do |m| m.module_name == module_name end
    end

    def input_for(mod)
      mod = find_module(mod) if mod.is_a? String
      return {} if start_modules.include?(mod)
      source_module = module_source(mod)
      raise 'No source module' unless source_module
      raise 'Source module not finished' unless source_module.run_status==:finished
      return source_module.module_output
    end

    def add_start_module(module_class,module_name,params={})
      mod = module_class.new(module_name, self, params)
      graph[mod] = []
      start_modules << mod
      mod
    end

    def add_module(module_class,module_name,after_module,params={})
      after_module = find_module(after_module) if after_module.is_a? String
      mod = module_class.new(module_name, self, params)
      graph[mod] = []
      graph[after_module] << mod
      mod
    end

    def run_status
      return :running     if graph.keys.any? do |mod| mod.run_status == :running end
      return :finished    if graph.keys.all? do |mod| mod.run_status == :finished end
      return :initialized if graph.keys.all? do |mod| mod.run_status == :initialized end
      return :error       if graph.keys.any? do |mod| mod.run_status == :error end
      return :cleaned     if graph.keys.all? do |mod| mod.run_status == :cleaned end
      return :paused
    end

    def reset_graph
      graph.keys.each do |mod| mod.reset_module end
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
      !graph.keys.any? do |mod| mod.run_status!=:finished end
    end

    def continue_execution
      traverse_modules = start_modules
      next_modules = []
      while !traverse_modules.empty? do
        traverse_modules = traverse_modules.each_with_object([]) do |mod,next_traverse|
          case mod.run_status
          when :initialized
            next_modules << mod
          when :finished
            next_traverse.concat graph[mod]
          else
          end
        end
      end

      if next_modules.any?
        log! "Continuing graph execution"
      else
        log! "Cannot continue graph execution, no modules ready to be ran"
      end

      next_modules.each do |mod|
        mod.execute_module()
      end
      graph_stopped
    end

    def module_finished(mod, execute_next=true)
      if execute_next
        graph[mod].each do |next_mod|
          next_mod.execute_module() if next_mod.autorun?
        end
      end
    end

    def module_error(mod, error)
      log! "Error executing module #{mod}", error
    end

    def graph_stopped
      log! "Graph execution stopped"
      graph_finished if finished?
    end

    def graph_finished
      log! "Graph execution finished"
    end
  end
end
