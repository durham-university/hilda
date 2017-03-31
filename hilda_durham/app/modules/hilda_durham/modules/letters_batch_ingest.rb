module HildaDurham
  module Modules
    class LettersBatchIngest
      include Hilda::ModuleBase
      include Hilda::Modules::WithJobTag

      def autorun?
        true
      end
      
      def dummy_graph
        @dummy_graph ||= Hilda::ModuleGraph.new.tap do |g|
          g.instance_variable_set(:@file_service, module_graph.file_service)
        end
      end
      
      def oubliette_module
        @oubliette_module ||= HildaDurham::Modules::OublietteIngest.new(dummy_graph).tap do |mod|
          mod.job_tag = self.job_tag
          mod.log = self.log
          mod.instance_variable_set(:@letters_graph, module_graph)
          class << mod
            def module_input
              @module_input ||= {}
            end
            def ingestion_log
              @letters_graph.combined_log.map(&:to_full_s).join("\n")
            end
          end
        end
      end
      
      def trifle_module
        @trifle_module ||= HildaDurham::Modules::TrifleIngest.new(dummy_graph).tap do |mod|
          mod.job_tag = self.job_tag
          mod.log = self.log
          class << mod
            def module_input
              @module_input ||= {}
            end
          end
        end
      end
      
      def set_sub_module_input(input, letter)
        input.clear
        input[:source_files] = letter[:source_files]
        input[:stored_files] = letter[:oubliette_files]
        input[:trifle_collection] = self.module_input[:trifle_collection]
        input[:file_metadata] = {}
        letter[:source_files].each_with_index do |(file_key,file), index|
          input[:file_metadata][:"#{file_key}__title"] = (index+1).to_s
        end
        source_link = nil
        if letter[:source_record].present?
          source_link = "schmit:#{letter[:source_record]}"
          source_link += "##{letter[:source_fragment]}" if letter[:source_fragment].present?
        end
        input[:process_metadata] = { 
          title: letter[:title],
          date: letter[:date],
          author: letter[:author],
          description: letter[:description],
          licence: self.module_input[:process_metadata].try(:[],:licence) || param_values[:licence],
          attribution: self.module_input[:process_metadata].try(:[],:attribution) || param_values[:attribution],
          source_record: source_link
        }
        input
      end
      
      def fetch_linked_metadata(source_id,fragment_id=nil)
        # returns a DurhamRails::RecordFormats::EADRecord (or TEIRecord) or a
        # subitem of one
        @cached_records ||= {}
        record = if @cached_records.key?(source_id)
          @cached_records[source_id]
        else
          log!(:info,"Fetching record #{source_id} from Schmit")
          schmit_record = Schmit::API::Catalogue.find(source_id)
          unless schmit_record
            log!(:error,"Couldn't find record #{source_id} in Schmit")
            return false
          end
          @cached_records[source_id] = schmit_record.xml_record
        end
        return false unless record
        record = record.sub_item(fragment_id) if fragment_id.present?
        record
      end
      
      def populate_source_metadata(letter_data)
        return true unless letter_data[:source_record].present?
        record = fetch_linked_metadata(letter_data[:source_record],letter_data[:source_fragment])
        return false unless record
        
        unless letter_data[:title].present?
          letter_data[:title] = (param_values[:title_base] || '') + (record.title || record.id)
        end
        letter_data[:date] = record.date || '' unless letter_data[:date].present?
        letter_data[:description] = record.scopecontent || '' unless letter_data[:description].present?
        letter_data[:author] = record.author || '' unless letter_data[:author].present?
        
        true
      end
      
      def ingest_oubliette(letter)
        log!(:info, "Ingesting #{letter[:title]} to Oubliette")
        set_sub_module_input(oubliette_module.module_input, letter)
        oubliette_module.module_output = {}
        
        oubliette_module.run_status = :running
        oubliette_module.run_module
        
        if oubliette_module.run_status == :error
          return false
        end
        letter[:oubliette_files] = oubliette_module.module_output[:stored_files]
        true
        # oubliette_module.module_output has :stored_files => array api_file.as_json, :stored_file_batch => batch.as_json
        # :stored_files includes 'temp_file' value
      end
      
      def ingest_trifle(letter)
        log!(:info, "Ingesting #{letter[:title]} to Trifle")
        set_sub_module_input(trifle_module.module_input, letter)
        trifle_module.module_output = {}
        
        trifle_module.run_status = :running
        trifle_module.run_module
        
        if trifle_module.run_status == :error
          return false
        end        
        
        manifest = trifle_module.module_output[:trifle_manifest]
        self.module_output[:trifle_manifests] ||= []
        self.module_output[:trifle_manifests].push(manifest['id'])
        log!(:info, "Trifle manifest id #{manifest['id']}")
        true
      end
      
      def letters
        @letters
      end
      
      def resolve_path(logical_path)
        root_path = param_values[:ingest_root]
        path = File.absolute_path(File.join(root_path,logical_path))
        root_path += File::SEPARATOR unless root_path.ends_with?(File::SEPARATOR)
        return nil unless path.start_with?(root_path)
        path
      end
      
      def list_files(logical_path)
        real_path = resolve_path(logical_path)
        return nil unless real_path
        re = /(?i)^.*\.tiff?$/
        Dir.glob(File.join(real_path,'*')).select do |f| f.match(re) end
      end
      
      def calculate_md5(path)
        File.open(path,'rb') do |readable|
          digest = Digest::MD5.new
          buf = ""
          while readable.read(16384, buf)
            digest.update(buf)
          end
          digest.hexdigest
        end
      end
      
      def metadata_file
        file_key = self.module_input[:source_files].keys.first
        self.module_input[:source_files][file_key]
      end
      
      def read_letters_data
        log!(:info, "Reading letters data")
        @letters = []
        file = metadata_file
        module_graph.file_service.get_file(file[:path]) do |open_file|
          open_file.each_line do |line|
            line = line.strip.force_encoding('UTF-8')
            next if line.start_with?('#') || line.blank?
            csv = line.parse_csv
            
            source_files = {}
            list_files(csv[0]).each do |file|
              file_name = File.basename(file)
              md5 = calculate_md5(file)
              log!(:info, "Found #{file}, MD5 is #{md5}")
              source_files[file_name] = {
                path: file,
                original_filename: file_name,
                content_type: 'image/tiff', # this is usually set by detect_content_type module rather than hard coded
                md5: calculate_md5(file)
              }
            end
            if source_files.empty?
              log!(:error, "Found no files in #{line[0]} for letter #{line[1]}.")
              return false
            end
            
            letter_data = {
              folder: csv[0],
              title: csv[1],
              author: csv[2],
              date: csv[3],
              description: csv[4],
              source_record: csv[5],
              source_fragment: csv[6],
              source_files: source_files
            }
            
            populate_source_metadata(letter_data)
            
            @letters << letter_data
            
            log!(:info,"Found letter #{letter_data[:title]} with #{source_files.count} files in #{letter_data[:folder]}")
          end
        end
        log!(:info,"Found #{@letters.count} letters.")
        true
      end
      
      def ingest_letter(letter)
        ingest_oubliette(letter) && \
          ingest_trifle(letter)
      end
      
      def run_module
        if !read_letters_data
          self.run_status = :error
          return
        end
        
        letters.each do |letter|
          unless ingest_letter(letter)
            self.run_status = :error
            log!(:error, "Unable to ingest letter #{letter[:title]}. Aborting.")
            break
          end
        end
      end
      
    end
  end
end
