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

      def run_module
        stored_files = {}
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
                original_filename: original_filename(file) )
              stored_files[file_key] = stored_file.as_json
              log! :info, "Ingested to Oubliette with id \"#{stored_file.id}\""
            end
          rescue StandardError => e
            log! :error, "Error ingesting file to Oubliette", e
            self.run_status = :error
          end
        end

        self.module_output = module_input.deep_dup.merge(stored_files: stored_files)
      end
    end
  end
end
