module HildaDurham
  module Modules
    class OublietteIngest
      include Hilda::ModuleBase

      def archival_files
        module_input[:source_files]
      end

      def file_title(file, key)
        module_input[:file_metadata].try(:[],:"#{key}__title") ||
          key.to_s || file[:original_filename] || "unnamed_file"
      end

      def original_filename(file)
        file[:original_filename] || 'unnamed_file'
      end

      def ingestion_log
        module_graph.combined_log.map(&:to_full_s).join("\n")
      end

      def autorun?
        true
      end
      
      def create_parent
        process_metadata = module_input[:process_metadata] || {}
        title = process_metadata.fetch(:title, "Unnamed batch")
        parent = Oubliette::API::FileBatch.create(title: title)
        unless parent
          log! :error, "Unable to create Oubliette file batch"
          self.run_status = :error
        else
          log! :info, "Create file batch in Oubliette with id \"#{parent.id}\""
        end
        parent
      end

      def run_module
        stored_files = {}
        parent = create_parent
        return unless parent
        archival_files.each_with_index do |(file_key,file),index|
          file_title = file_title(file, file_key)
          log! :info, "Ingesting file to Oubliette: #{file_key}"
          begin
            module_graph.file_service.get_file(file[:path]) do |open_file|
              stored_file = Oubliette::API::PreservedFile.ingest(open_file,
                title: file_title,
                ingestion_checksum: "md5:#{file[:md5]}",
                ingestion_log: ingestion_log,
                content_type: file[:content_type] || 'application/octet-stream',
                original_filename: original_filename(file),
                parent: parent )
              stored_files[file_key] = stored_file.as_json
              log! :info, "Ingested to Oubliette with id \"#{stored_file.id}\""
            end
          rescue StandardError => e
            log! :error, "Error ingesting file to Oubliette", e
            self.run_status = :error
          end
        end

        self.module_output = module_input.deep_dup.merge(stored_files: stored_files, stored_file_batch: parent.try(:as_json))
      end
    
      def rollback
        sent_files = self.module_output.try(:[],:stored_files)
        if sent_files
          sent_files.each do |file_key,file_json|
            f = Oubliette::API::PreservedFile.from_json(file_json)
            self.module_graph.log!("Removing file from Oubliette #{f.id}")
            begin
              f.destroy
            rescue StandardError => e
            end
          end
        end
        file_batch_json = self.module_output.try(:[],:stored_file_batch)
        if file_batch_json
          file_batch = Oubliette::API::FileBatch.from_json(file_batch_json)
          self.module_graph.log!("Removing file batch from Oubliette #{file_batch.id}")
          begin
            file_batch.destroy
          rescue StandardError => e
          end
        end
        return super
      end
      
    end    
  end
end
