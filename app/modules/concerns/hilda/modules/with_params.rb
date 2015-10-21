module Hilda::Modules
  module WithParams
    extend ActiveSupport::Concern

    attr_accessor :param_defs

    def receive_params(params)
      # Don't clear param_values, there might be other needed stuff in there
      # besides submitted params

      if params.keys.any? do |key| param_defs[key.to_sym].try(:[],:type)==:file end
        raise 'In order to receive files, you must override receive_params'
      end

      param_defs.each do |key,param|
        self.param_values[key] = params[key.to_s] if params.key?(key.to_s)
      end

      changed!
      return true
    end

    def got_all_param_values?
      return false unless param_values
      return false unless param_defs.try(:any?)
      param_defs.each do |key,param|
        return false unless param_values[key].present?
      end
      return true
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


    module ClassMethods

      def sanitise_field_defs(fields)
        fields.each_with_object({}) do |(original_key,field),o|
          key = original_key.to_s.gsub(/[^a-zA-Z0-9_]/,'_').to_sym
          field_data = {}
          if field.is_a?(String) || field.is_a?(Symbol)
            field_data[:label] = original_key
            field_data[:type] = field.to_sym
            field_data[:default] = nil
            field_data[:group] = nil
          elsif field.is_a? Hash
            field_data[:label] = (field[:label] || field['label'] || original_key).to_s
            field_data[:type] = (field[:type] || field['type'] || :string).to_sym
            field_data[:default] = (field[:default] || field['default'])
            field_data[:group] = (field[:group] || field['group'])
          end
          o[key] = field_data
        end
      end
    end
  end
end
