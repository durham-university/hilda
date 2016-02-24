module Hilda::Modules
  module WithParams
    extend ActiveSupport::Concern

    attr_accessor :param_defs

    def receive_params(params)
      raise "Module cannot receive params in current state" unless can_receive_params?
      # Don't clear param_values, there might be other needed stuff in there
      # besides submitted params

      if params.keys.any? do |key| param_defs[key.to_sym].try(:[],:type)==:file end
        raise 'In order to receive files, you must override receive_params'
      end

      param_defs.each do |key,param|
        self.param_values[key] = params[key.to_s] if params.key?(key.to_s)
      end
      
      check_submitted_status!

      changed!
      return true
    end

    def param_values_with_defaults
      values = {}
      param_defs.each do |key,param|
        value = param_values.try(:[],key)
        value = param[:default] unless value.present?
        values[key] = value if value.present?
      end
      values
    end

    def all_params_submitted?
      return false unless param_defs.try(:any?)
      param_defs.each do |key,param|
        return false unless param_values_with_defaults.key?(key) || param_defs[key][:optional]
      end
      return true
    end

    def all_params_valid?
      return false unless all_params_submitted?
      values = param_values_with_defaults
      param_defs.each do |key,param|
        return false unless validate_param(key,values[key])
      end
      return true
    end
    
    def check_submitted_status!
      if all_params_valid?
        self.run_status = :submitted if run_status==:initialized
      else
        self.run_status = :initialized if run_status==:submitted
      end
    end    

    def from_json(json)
      super(json) do |json|
        self.param_defs = self.class.sanitise_field_defs(json[:param_defs])
        yield(json) if block_given?
      end
    end

    def as_json(*args)
      super(*args).tap do |json|
        json[:param_defs] = param_defs
      end
    end

    def validate_param(key,value)
      return value.present? || param_defs[key][:optional]
    end

    def submitted_params
      self.param_values_with_defaults.slice(*self.param_defs.keys)
    end

    def ready_to_run?
      super && all_params_valid?
    end

    def params_output_key
      self.param_values.fetch(:output_key, :submitted_params)
    end    

    def run_module
      unless all_params_valid?
        log! :error, 'Submitted values are not valid, cannot proceed.'
        self.run_status = :error
        return
      end

      self.module_output = module_input.deep_dup.deep_merge({
        params_output_key => submitted_params
      })
    end


    module ClassMethods

      def sanitise_field_defs(fields)
        fields.each_with_object({}) do |(key,field),o|
          key = key.to_sym
          field_data = {}
          if field.is_a?(String) || field.is_a?(Symbol)
            field_data[:label] = key.to_s
            field_data[:type] = field.to_sym
            field_data[:default] = nil
            field_data[:group] = nil
            field_data[:optional] = false
            field_data[:collection] = nil
          elsif field.is_a? Hash
            field_data[:label] = (field[:label] || field['label'] || key).to_s
            field_data[:type] = (field[:type] || field['type'] || :string).to_sym
            field_data[:default] = (field[:default] || field['default'])
            field_data[:group] = (field[:group] || field['group'])
            field_data[:optional] = (field[:optional] || field['optional'] || false)
            field_data[:collection] = (field[:collection] || field['collection'])
          end
          o[key] = field_data
        end
      end
    end
  end
end
