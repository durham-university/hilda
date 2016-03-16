module HildaDurham
  module Modules
    class LibraryLinker
      include Hilda::ModuleBase
      include Hilda::Modules::WithParams

      def initialize(module_graph, param_values={})
        super(module_graph, param_values)
        self.param_values.merge!({form_template: 'hilda_durham/modules/library_linker_form'})
        self.param_defs = {}
        self.param_defs[:library_record_type] = {
            label: 'Record type', 
            type: :select,
            collection: ['adlib','millenium']
          }
        # Collection id not needed yet for anything. In the future some systems
        # might need to specify the collection where the record can be found in
        # addition to the record id.
#        self.param_defs[:library_collection_id] = { 
#            label: 'Collection id',
#            type: :string
#          }
        self.param_defs[:library_record_id] = {
            label: 'Record id',
            type: :string
          }
      end

      def selected_record
        record_id = self.param_values[:library_record_id]
        return nil unless record_id
        begin
          case self.param_values[:library_record_type].to_sym
          when :adlib
            record = DurhamRails::LibrarySystems::Adlib.connection.record(record_id)
          when :millenium
            record = DurhamRails::LibrarySystems::Millenium.connection.record(record_id)
          else
            return nil
          end
          return nil unless record.exists?
          return record
        rescue StandardError => e
          return nil
        end
      end
      
      def receive_params(params)
        return super(params).tap do |ret|
          fetch_selected_record_label
        end
      end
      
      def fetch_selected_record_label
        # TODO: Probably need a bit more information in the label.
        self.param_values[:selected_library_record_label] = begin
          record = selected_record
          case record
          when DurhamRails::RecordFormats::AdlibRecord
            record.other_name
          when DurhamRails::RecordFormats::MilleniumRecord
            record.title
          else
            nil
          end
        end
        changed!
      end
      
      def selected_record_label
        # cache this to avoid polling other services excessively
        self.param_values[:selected_library_record_label]
      end

      def validate_reference
        selected_record.present?
      end

      def run_module
        unless all_params_valid?
          log! :error, 'Library link not yet submitted, cannot proceed.'
          self.run_status = :error
          return
        end

        unless validate_reference
          log! :error, 'Invalid reference'
          self.run_status = :error
          return
        end

        self.module_output = module_input.deep_dup.merge({
          library_link: {
            type: self.param_values[:library_record_type],
            record_id: self.param_values[:library_record_id]
          }
        })
      end

    end
  end
end
