module HildaDurham
  module Modules
    class OublietteIngestInto < OublietteIngest
      
      def create_parent
        process_metadata = module_input[:process_metadata] || {}

        file_batch_id = process_metadata[:oubliette_file_batch_id]
# no arks in oubliette
#        file_batch_id = file_batch_id.split('/').last if file_batch_id.try(:start_with?,'ark:')
        unless file_batch_id.present?
          log! :error, "oubliette file batch id not given"
          self.run_status = :error
          return nil
        end
        
        parent = Oubliette::API::FileBatch.find(file_batch_id)
        log!(:error, "Couldn't find file batch #{file_batch_id} in oubliette") unless parent.present?
        parent
      end

      def run_module
        super
        self.module_output = self.module_output.except(:stored_file_batch) if self.module_output
      end
        
    end    
  end
end
