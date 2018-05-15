module HildaDurham
  module Modules
    # Originally created for batch ingesting letters. Now used for all kinds of other items
    # as well.
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
      
      def validation_module
        @validation_module ||= Hilda::Modules::FitsValidator.new(dummy_graph, validation_rules: param_values[:validation_rules]).tap do |mod|
          mod.log = self.log
          class << mod
            def module_input
              @module_input ||= {}
            end
          end
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
              full_log = @letters_graph.combined_log
              if full_log.count > 100
                full_log = full_log[0..49] + [DurhamRails::Log::LogMessage.new(:info,"... (#{full_log.count-100} messages pruned)",nil,DateTime.now)] + full_log[-50..-1]
              end
              full_log.map(&:to_full_s).join("\n")              
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
          input[:file_metadata][:"#{file_key}__title"] = file[:title].present? ? file[:title] : ((index+1).to_s)
        end
        source_link = nil
        if letter[:source_record].present?
          source_link = letter[:source_record]
          source_link = "schmit:#{source_link}" unless source_link.starts_with?("millennium:") || source_link.starts_with?("schmit:") || source_link.starts_with?("adlib:")
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
      
      def fetch_millennium_metadata(source_id, fragment_id=nil)
        source_id = source_id[11..-1] if source_id.start_with?("millennium:")
        
        @cached_records ||= {}
        record = if @cached_records.key?("millennium:#{source_id}")
          @cached_records["millennium:#{source_id}"]
        else
          log!(:info,"Fetching record #{source_id} from Millennium")
          millennium_record = DurhamRails::LibrarySystems::Millennium.connection.record(source_id)
          unless millennium_record
            log!(:error,"Couldn't find record #{source_id} in Millennium")
            return nil
          end
          @cached_records["millennium:#{source_id}"] = millennium_record
        end
        return nil unless record
        record = record.holdings.find do |h| h.holding_id == fragment_id end if fragment_id.present?
        return nil unless record
        {
          id: record.recordkey,
          title: record.title,
          date: nil,
          description: nil,
          author: record.author
        }
      end

      def fetch_adlib_metadata(source_id, fragment_id=nil)
        source_id = source_id[6..-1] if source_id.start_with?("adlib:")
        
        @cached_records ||= {}
        record = if @cached_records.key?("adlib:#{source_id}")
          @cached_records["adlib:#{source_id}"]
        else
          log!(:info,"Fetching record #{source_id} from Adlib")
          adlib_record = DurhamRails::LibrarySystems::Adlib.connection.record(source_id)
          unless adlib_record
            log!(:error,"Couldn't find record #{source_id} in Adlib")
            return nil
          end
          @cached_records["adlib:#{source_id}"] = adlib_record
        end
        return nil unless record
        {
          id: record.priref,
          title: record.title,
          date: record.date,
          description: record.description,
          author: record.author,
          # source lookup might have been done with object_identifier but we want
          # to store priref instead
          source_record: "adlib:#{record.priref}" 
        }
      end
      
      def fetch_schmit_metadata(source_id, fragment_id=nil)
        source_id = source_id[7..-1] if source_id.start_with?("schmit:")
        
        @cached_records ||= {}
        record = if @cached_records.key?("schmit:#{source_id}")
          @cached_records["schmit:#{source_id}"]
        else
          log!(:info,"Fetching record #{source_id} from Schmit")
          schmit_record = Schmit::API::Catalogue.find(source_id)
          unless schmit_record
            log!(:error,"Couldn't find record #{source_id} in Schmit")
            return nil
          end
          @cached_records["schmit:#{source_id}"] = schmit_record.xml_record
        end
        return nil unless record
        record = record.sub_item(fragment_id) if fragment_id.present?
        return nil unless record
        {
          id: record.id,
          title: record.title,
          date: record.date,
          description: record.scopecontent,
          author: record.author
        }
      end
      
      def fetch_linked_metadata(source_id,fragment_id=nil)
        if source_id.start_with?("millennium:")
          fetch_millennium_metadata(source_id,fragment_id)
        elsif source_id.start_with?("schmit:")
          fetch_schmit_metadata(source_id,fragment_id)
        elsif source_id.start_with?("adlib:")
          fetch_adlib_metadata(source_id, fragment_id)
        else
          fetch_schmit_metadata(source_id,fragment_id)
        end
      end
      
      def populate_source_metadata(letter_data)
        return true unless letter_data[:source_record].present?
        record = fetch_linked_metadata(letter_data[:source_record],letter_data[:source_fragment])
        return false unless record
        
        unless letter_data[:title].present?
          letter_data[:title] = (param_values[:title_base] || '') + (record[:title] || record[:id])
        end
        letter_data[:date] = record[:date] || '' unless letter_data[:date].present?
        letter_data[:description] = record[:description] || '' unless letter_data[:description].present?
        letter_data[:author] = record[:author] || '' unless letter_data[:author].present?
        # rewrite source_record, this allows us to do source lookups with different
        # identifiers than what we actually store
        letter_data[:source_record] = record[:source_record] if record[:source_record].present?
        true
      end
      
      def ingest_oubliette(letter)
        log!(:info, "Ingesting #{letter[:title]} to Oubliette")
        set_sub_module_input(oubliette_module.module_input, letter)
        oubliette_module.module_output = {}
        oubliette_module.job_tag = self.job_tag + '/' + letter[:folder]
        
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
        trifle_module.job_tag = self.job_tag + '/' + letter[:folder]
        
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
        log!(:info, "Reading item data")
        @letters = []
        file = metadata_file
        module_graph.file_service.get_file(file[:path]) do |open_file|
          open_file.each_line do |line|
            line = line.strip.force_encoding('UTF-8')
            next if line.start_with?('#') || line.blank?
            csv = line.parse_csv
            
            source_files = {}
            if csv.length >= 8
              csv[7].split(';').each do |f|
                file = File.join(resolve_path(csv[0]),f)
                file_name = File.basename(file)
                md5 = calculate_md5(file)
                log!(:info, "Using file #{file}, MD5 is #{md5}")
                source_files[file_name] = {
                  path: file,
                  original_filename: file_name,
                  content_type: 'image/tiff',
                  md5: md5
                }
              end
            else
              list_files(csv[0]).each do |file|
                file_name = File.basename(file)
                md5 = calculate_md5(file)
                log!(:info, "Found #{file}, MD5 is #{md5}")
                source_files[file_name] = {
                  path: file,
                  original_filename: file_name,
                  content_type: 'image/tiff', # this is usually set by detect_content_type module rather than hard coded
                  md5: md5
                }
              end
            end
            
            if source_files.empty?
              log!(:error, "Found no files in #{csv[0]} for item #{csv[1]}.")
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
            
            log!(:info,"Found item #{letter_data[:title]} with #{source_files.count} files in #{letter_data[:folder]}")
          end
        end
        log!(:info,"Found #{@letters.count} letters.")
        true
      end
      
      def ingest_letter(letter)
        set_letter_metadata(letter)
        ingest_oubliette(letter) && \
          ingest_trifle(letter)
      end
      
      def set_letter_metadata(letter)
        if self.param_values[:file_sorter]
          letter[:source_files] = self.param_values[:file_sorter].constantize.sort(letter[:source_files])
        end
        if self.param_values[:defaults_setter]
          letter_files = letter[:source_files].map do |file_key, file_data| file_data[:original_filename] end
          labels = self.param_values[:defaults_setter].constantize.default_file_labels(letter_files)
          letter[:source_files].zip(labels).each do |(file_key, file_data), label|
            file_data[:title] = label
          end
        end
      end
      
      def validate_letter(letter)
        log!(:info, "Validating #{letter[:title]}")
        set_sub_module_input(validation_module.module_input, letter)
        validation_module.module_output = {}
        
        validation_module.run_status = :running
        validation_module.run_module
        
        return false if validation_module.run_status == :error
        true        
      end
      
      def run_module
        if !read_letters_data
          self.run_status = :error
          return
        end
        
        if param_values[:validation_rules].present?
          all_ok = true
          letters.each do |letter|
            all_ok &= validate_letter(letter)
          end
          unless all_ok
            self.run_status = :error
            log!(:error, "Validation failed, stopping")
            return
          end
        end
        
        letters.each do |letter|
          unless ingest_letter(letter)
            self.run_status = :error
            log!(:error, "Unable to ingest item #{letter[:title]}. Aborting.")
            break
          end
        end
      end
      
    end
  end
end
