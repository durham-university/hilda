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
        super(parse_bulk_params(params))
      end
    end
    
    def groups
      (param_defs || {}).map do |k,x| x[:group] end .uniq
    end

    def parse_bulk_params(params)
      
      defs_by_group = (param_defs || {}).map do |k,v| v.merge(key: k) end \
                                       .group_by do |x| x[:group] end
      
      lines = (params[data_key] || '').split(/\r?\n/)
      
      {}.tap do |new_params|
        defs_by_group.each_with_index do |(group,params),i|
          line = lines[i] || ''
          if data_delimiter
            values = line.split(data_delimiter) 
          else
            values = [line]
          end
          
          params.zip(values).each do |param,value|
            new_params[param[:key].to_s] = value unless value.nil?
          end
        end
      end
    end
    
  end
end
