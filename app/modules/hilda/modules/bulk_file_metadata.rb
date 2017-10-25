module Hilda::Modules
  class BulkFileMetadata < FileMetadata

    def initialize(*args)
      super(*args)
      self.param_values.merge!({form_template: 'hilda/modules/bulk_metadata_form'})
    end
    
    def data_delimiter
      self.param_values.fetch(:data_delimiter, nil)
    end
    
    def data_key
      self.param_values.fetch(:data_key,'bulk_data')
    end

    def receive_params(params)
      unless params[data_key].nil?
        self.param_values[:bulk_data] = params[data_key]
        super(parse_bulk_params)
      end
    end
    
    def all_params_valid?
      return false unless super
      return false unless groups.length == bulk_data_lines.length
      return true
    end
    
    def set_default_values
      super
      if self.param_values[:defaults_setter].present?
        labels = self.param_values[:defaults_setter].constantize.default_file_labels(self.groups)
        self.receive_params({data_key => labels.join("\n")}) unless labels.nil? || !self.can_receive_params?
      end
    end
        
    def bulk_data_lines
      (self.param_values[:bulk_data] || '').split(/\r?\n/)
    end

    def parse_bulk_params
      defs_by_group = (param_defs || {}).map do |k,v| v.merge(key: k) end \
                                       .group_by do |x| x[:group] end
      
      lines = bulk_data_lines
      
      {}.tap do |new_params|
        defs_by_group.each_with_index do |(group,params),i|
          line = lines[i] || ''
          if data_delimiter
            values = line.parse_csv(col_sep: data_delimiter).map do |val|
              val = val.try(:strip)
              val.present? ? val : nil
            end
          else
            values = [line.strip]
          end
          
          params.zip(values).each do |param,value|
            new_params[param[:key].to_s] = value unless value.nil?
          end
        end
      end
    end
    
  end
end
