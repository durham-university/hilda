module HildaDurham
  module Modules
    class TrifleIngestInto < TrifleIngest

      def run_module
        process_metadata = module_input[:process_metadata] || {}

        manifest_id = process_metadata[:trifle_manifest_id]
        manifest_id = manifest_id.split('/').last if manifest_id.try(:start_with?,'ark:')
        unless manifest_id.present?
          log! :error, "trifle manifest id not given"
          self.run_status = :error
          return
        end

        deposit_items = build_deposit_items

        begin
          response = nil
          self.retry(Proc.new do |error, counter|
            delay = 10+30*counter
            log! :warning, "Error depositing images to Trifle, retrying after #{delay} seconds", error
            delay
          end, 5) do          
            response = Trifle::API::IIIFManifest.deposit_into(manifest_id, deposit_items)
          end
        rescue StandardError => e
          log! :error, "Error depositing images to Trifle", e
          self.run_status = :error
          return
        end
        
        if response[:status]=='ok'
          log! :info, "Ingested to Trifle manifest #{manifest_id}"
        else
          log! :error, "Error depositing images to Trifle. #{response[:message]}"
          self.run_status = :error
          return
        end

        self.module_output = module_input.deep_dup.merge(trifle_manifest: response[:resource].as_json)
      end

      def rollback
      end

    end
  end
end