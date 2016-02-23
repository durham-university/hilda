module HildaDurham
  module Modules
    class TrifleIngest
      include Hilda::ModuleBase
      
      
      def autorun?
        true
      end
      
      def ingest_files
        module_input[:stored_files]
      end

      def run_module
        deposit_items = ingest_files.map do |file_key,file_json|
          file = Oubliette::API::PreservedFile.from_json(file_json)
          { source_path: file.download_url, title: file.title }
        end
        
        begin
          response = Trifle::API::IIIFManifest.deposit_new(deposit_items)
        rescue StandardError => e
          log! :error, "Error depositing images to Trifle", e
          self.run_status = :error
        end
        
        if response[:status]=='ok'
          log! :info, "Ingested to Trifle. Manifest id is #{response[:resource].id}"
        else
          log! :error, "Error depositing images to Trifle. #{response[:message]}"
          self.run_status = :error
        end

        self.module_output = module_input.deep_dup.merge(trifle_manifest: response[:resource].as_json)
      end
            
      def rollback
        manifest_json = self.module_output.try(:[],:trifle_manifest)
        if manifest_json
          m = Trifle::API::IIIFManifest.from_json(manifest_json)
          self.module_graph.log!("Removing manifest from Trifle #{m.id}")
          begin
            m.destroy
          rescue StandardError => e
          end
        end
        return super
      end
                  
    end
  end
end

