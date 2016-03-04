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
        unless module_input[:trifle_collection].present?
          log! :error, "trifle_collection is not set in module input"
          self.run_status = :error
          return
        end

        deposit_items = ingest_files.map do |file_key,file_json|
          file = Oubliette::API::PreservedFile.from_json(file_json)
          { source_path: file.download_url, 'title' => file.title }
        end
        
        process_metadata = module_input[:process_metadata] || {}
        
        manifest_metadata = {
          'title' => process_metadata[:title],
          'date_published' => process_metadata[:date],
          'author' => [process_metadata[:author]],
          'description' => process_metadata[:description],
          'licence' => process_metadata[:licence],
          'attribution' => process_metadata[:attribution]
        }
        
        begin
          parent = Trifle::API::IIIFCollection.find(module_input[:trifle_collection])
          response = Trifle::API::IIIFManifest.deposit_new(parent, deposit_items, manifest_metadata)
        rescue StandardError => e
          log! :error, "Error depositing images to Trifle", e
          self.run_status = :error
          return
        end
        
        if response[:status]=='ok'
          log! :info, "Ingested to Trifle. Manifest id is #{response[:resource].id}"
        else
          log! :error, "Error depositing images to Trifle. #{response[:message]}"
          self.run_status = :error
          return
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

