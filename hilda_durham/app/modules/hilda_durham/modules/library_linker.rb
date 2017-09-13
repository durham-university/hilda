module HildaDurham
  module Modules
    class LibraryLinker
      include Hilda::ModuleBase
      include Hilda::Modules::WithParams
      include DurhamRails::Retry

      def initialize(module_graph, param_values={})
        super(module_graph, param_values)
        self.param_values.merge!({form_template: 'hilda_durham/modules/library_linker_form'})
        self.param_defs = {}
        self.param_defs[:library_record_type] = {
            label: 'Record type', 
            type: :select,
            collection: ['Adlib','Millennium','Schmit']
          }
        self.param_defs[:library_record_id] = {
            label: 'Record id',
            note: 'Adlib or Millennium record ID. For Schmit use ARK identifier of the catalogue.',
            type: :string
          }
        self.param_defs[:library_record_fragment] = { 
            label: 'Fragment id',
            note: 'For Schmit enter the unitid of the record in the catalogue. For Millennium, optionally select the holding',
            type: :string,
            optional: true
          }
      end

      def selected_record(log_errors = false)
        record_type = self.param_values[:library_record_type].try(:downcase)
        record_id = self.param_values[:library_record_id]
        fragment_id = self.param_values[:library_record_fragment]
        return nil unless record_id.present?
        cached_record = "#{record_type}:#{record_id}##{fragment_id}"
        @selected_record = nil unless @cached_record == cached_record
        @cached_record = cached_record
        @selected_record ||= begin
          record = case record_type.to_sym
            when :adlib
              DurhamRails::LibrarySystems::Adlib.connection.record(record_id)
            when :millennium
              r = DurhamRails::LibrarySystems::Millennium.connection.record(record_id)
              if r && r.exists? && fragment_id.present?
                r = r.holdings.find do |h| h.holding_id == fragment_id end
              end
              r
            when :schmit
              r = nil
              self.retry(Proc.new do |error, counter|
                raise error if error.is_a?(Schmit::API::FetchError)
                delay = 10+30*counter
                log! :warning, "Error fetching record from Schmit, retrying after #{delay} seconds", error
                delay
              end, self.run_status==:running ? 5 : 0) do # don't retry outside run_module
                r = Schmit::API::Catalogue.find(record_id)
              end
              if r
                fragment_id.present? ? r.xml_record.sub_item(fragment_id) : r.xml_record.root_item
              else
                nil
              end
            else
              nil
            end
          record.exists? ? record : nil
        rescue StandardError => e
          log!(:error,e) if log_errors
          nil
        end
      end
      
      def set_check_digit
        record_type = self.param_values[:library_record_type].try(:downcase)
        if record_type == 'millennium'
          record_id = self.param_values[:library_record_id]
          if record_id.present? && record_id.length == 8 && record_id[0] == 'b'
            check_digit = DurhamRails::LibrarySystems::Millennium.check_digit(record_id)
            if check_digit.present?
              self.param_values[:library_record_id] += check_digit
            end
          end
        end
      end
      
      def receive_params(params)
        return super(params).tap do |ret|
          set_check_digit
          fetch_selected_record_label
          update_fragment_options
        end
      end
      
      def fetch_selected_record_label
        # TODO: Probably need a bit more information in the label.
        self.param_values[:selected_library_record_label] = begin
          record = selected_record
          case record
          when DurhamRails::RecordFormats::AdlibRecord
            record.title
          when DurhamRails::RecordFormats::MillenniumRecord, DurhamRails::RecordFormats::MillenniumRecord::Holding
            record.title
          when DurhamRails::RecordFormats::EADRecord::Item, DurhamRails::RecordFormats::TEIRecord::Impl
            record.title_path
          else
            nil
          end
        end
        changed!
      end
      
      def update_fragment_options
        record = selected_record
        options = case record
          when DurhamRails::RecordFormats::MillenniumRecord
            count = record.holdings.count
            [["#{count} #{"holding".pluralize(count)}",nil]] + record.holdings.map do |h| [h.holding_title,h.holding_id] end
          when DurhamRails::RecordFormats::MillenniumRecord::Holding
            count = record.parent.holdings.count
            [["#{count} #{"holding".pluralize(count)}",nil]] + record.parent.holdings.map do |h| [h.holding_title,h.holding_id] end
          else
            nil
        end
        
        if options==nil
          self.param_defs[:library_record_fragment][:type] = :string
          self.param_defs[:library_record_fragment][:collection] = nil          
        else
          self.param_defs[:library_record_fragment][:type] = :select
          self.param_defs[:library_record_fragment][:collection] = options
        end
        
        changed!
      end
      
      def selected_record_label
        # cache this to avoid polling other services excessively
        self.param_values[:selected_library_record_label]
      end

      def validate_reference
        selected_record(true).present?
      end
      
      def adapt_record_to_params
        record = selected_record
        
        source_record = "#{self.param_values[:library_record_type].downcase}:#{self.param_values[:library_record_id]}"
        source_record += "##{self.param_values[:library_record_fragment]}" if self.param_values[:library_record_fragment].present?
        { source_record: source_record }.merge(
          case record
          when DurhamRails::RecordFormats::AdlibRecord
            { title: record.title }
          when DurhamRails::RecordFormats::MillenniumRecord
            { title: record.title }
          when DurhamRails::RecordFormats::EADRecord::Item, DurhamRails::RecordFormats::TEIRecord::Impl
            { 
              title: record.title_path,
              date: record.date,
              author: record.author, 
              description: record.scopecontent
            }
          else
            {}
          end
        )
      end

      def run_module
        unless all_params_valid?
          log! :error, 'Library link not yet submitted, cannot proceed.'
          self.run_status = :error
          return
        end

        unless validate_reference
          log! :error, 'Couldn\'t find linked record'
          self.run_status = :error
          return
        end

        self.module_output = module_input.deep_dup.deep_merge({
          library_link: {
            type: self.param_values[:library_record_type].downcase,
            record_id: self.param_values[:library_record_id],
            fragment_id: self.param_values[:library_record_fragment]
          },
          process_metadata: adapt_record_to_params
        })
      end

    end
  end
end
