module HildaDurham
  module Modules
    class TrifleIngest
      include Hilda::ModuleBase
      include DurhamRails::Retry      
      include Hilda::Modules::WithJobTag
      
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

        process_metadata = module_input[:process_metadata] || {}

        deposit_items = ingest_files.map do |file_key,file_json|
          file = Oubliette::API::PreservedFile.from_json(file_json)
          image_hash = { 'source_path' => "oubliette:#{file.id}", 'title' => file.title, 'temp_file' => file_json['temp_file'] }
          image_hash['conversion_profile'] = process_metadata[:conversion_profile] if process_metadata.key?(:conversion_profile)
          image_hash
        end
                
        title = process_metadata[:title]
        title += process_metadata[:subtitle] if process_metadata[:subtitle].present?
        
        manifest_metadata = {
          'title' => title,
          'digitisation_note' => process_metadata[:digitisation_note],
          'date_published' => process_metadata[:date],
          'author' => [process_metadata[:author]].compact,
          'description' => process_metadata[:description],
          'licence' => process_metadata[:licence],
          'attribution' => process_metadata[:attribution],
          'source_record' => process_metadata[:source_record],
          'job_tag' => job_tag+'/deposit'
        }
        
        begin
          parent = nil
          response = nil
          self.retry(Proc.new do |error, counter|
            raise error if error.is_a?(Trifle::API::FetchError)
            delay = 10+30*counter
            log! :warning, "Error fetching collection from Trifle, retrying after #{delay} seconds", error
            delay
          end, 5) do          
            parent = Trifle::API::IIIFCollection.find(module_input[:trifle_collection])
          end
          self.retry(Proc.new do |error, counter|
            delay = 10+30*counter
            log! :warning, "Error depositing images to Trifle, retrying after #{delay} seconds", error
            delay
          end, 5) do          
            response = Trifle::API::IIIFManifest.deposit_new(parent, deposit_items, manifest_metadata)
          end
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

