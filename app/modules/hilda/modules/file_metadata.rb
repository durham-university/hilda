module Hilda::Modules
  class FileMetadata
    include Hilda::ModuleBase
    include Hilda::Modules::WithParams

    attr_accessor :metadata_fields

    def initialize(module_graph, param_values={})
      super(module_graph, param_values)
      self.metadata_fields = self.class.sanitise_field_defs(param_values.fetch(:metadata_fields,{}))
      self.param_defs = {}
    end

    def groups
      (param_defs || {}).map do |k,x| x[:group] end .uniq
    end

    def build_param_defs
      self.param_defs = self.class.sanitise_field_defs( (module_graph.graph_params[:source_file_names] || []).each_with_object({}) do |file_name,defs|
        metadata_fields.each_with_object(defs) do |(key,field),defs|
          defs["#{file_name}__#{key}".to_sym] = {
            group: file_name,
            label: field[:label],
            type: field[:type],
            default: ( field[:default] == '__key__' ? file_name : field[:default] ),
            optional: field.fetch(:optional, false)
          }
        end
      end )
    end

    def from_json(json)
      super(json) do |json|
        self.metadata_fields = self.class.sanitise_field_defs(json[:metadata_fields])
        yield(json) if block_given?
      end
    end

    def as_json(*args)
      super(*args).tap do |json|
        json[:metadata_fields] = metadata_fields
      end
    end
    
    def graph_params_changed
      super
      old_defs = self.param_defs
      build_param_defs
      set_default_values
      check_submitted_status!
      changed! unless old_defs == self.param_defs
    end
    
    def set_default_values
      # bulk_file_metadata uses this, not implemented here
    end

    def params_output_key
      :file_metadata
    end
  end
end
