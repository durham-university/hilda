module HildaDurham
  module Modules
    class TrifleCollectionLinker
      include Hilda::ModuleBase
      include Hilda::Modules::WithParams
      include DurhamRails::Retry

      def initialize(module_graph, param_values={})
        super(module_graph, param_values)
        self.param_values.merge!({form_template: 'hilda_durham/modules/trifle_collection_linker_form'})
        self.param_defs = {}
        self.param_defs[:trifle_root_collection] = {
            label: 'Root collection', # labels aren't really used since the form template is overridden
            type: :string
          }
        self.param_defs[:trifle_sub_collection] = {
            label: 'Sub collection',
            type: :string,
            optional: true
          }
      end

      def query_module(params)
        query = params[:trifle_query].try(:downcase) || ''
        res = nil
        begin
          case params[:trifle_type].to_sym
          when :root_collection
            res = Trifle::API::IIIFCollection.all # all is really only root collections
          when :sub_collection
            root_id = params[:trifle_root_collection]
            root = Trifle::API::IIIFCollection.find(root_id)
            res = Trifle::API::IIIFCollection.all_in_collection(root)
          else
            return { status: 'ERROR', error_message: 'invalid query type' }
          end
        rescue Trifle::API::FetchError => e
          return { status: 'ERROR', error_message: "Unable to get objects. #{e.message}"}
        end

        res.select! do |obj|
          obj.title.try(:index,query)
        end if query.present?

        return {
          status: 'OK',
          result: res.map do |obj|
                    obj.as_json.slice('id','title')
                  end .sort do |a,b|
                    a[:title] <=> b[:title]
                  end
        }
      end

      def validate_reference
        begin
          root_collection = nil
          sub_collectiont = nil
          self.retry(Proc.new do |error, counter|
            raise error if error.is_a?(Trifle::API::FetchError)
            delay = 10+30*counter
            log! :warning, "Error validating collection record in Trifle, retrying after #{delay} seconds", error
            delay
          end, 5 ) do
            # Three potential failure points in this block. Don't need to retry
            # the first ones if the latter ones fail. (Although note that
            # sub_collection might be nil)
            root_collection ||= current_root_collection 
            sub_collection ||= current_sub_collection

            return false unless root_collection

            # TODO: Trifle::API should have some better way to check that a collection is under some other collection
            return false if sub_collection && !Trifle::API::IIIFCollection.all_in_collection(root_collection).map(&:id).include?(sub_collection.id)
          end

          return true
        rescue Trifle::API::FetchError => e
          return false
        end
      end

      def run_module
        unless all_params_valid?
          log! :error, 'Trifle link not yet submitted, cannot proceed.'
          self.run_status = :error
          return
        end

        unless validate_reference
          log! :error, 'Invalid reference'
          self.run_status = :error
          return
        end

        self.module_output = module_input.deep_dup.merge({
          trifle_collection: param_values[:trifle_sub_collection].present? ? param_values[:trifle_sub_collection] : param_values[:trifle_root_collection]
        })
      end

      def current_root_collection
        @current_root_collection ||= begin
          (self.param_values && self.param_values[:trifle_root_collection]) ? Trifle::API::IIIFCollection.find(self.param_values[:trifle_root_collection]) : nil
        rescue Trifle::API::FetchError
          nil
        end
      end

      def current_sub_collection
        @current_sub_collection ||= begin
          (self.param_values && self.param_values[:trifle_sub_collection]) ? Trifle::API::IIIFCollection.find(self.param_values[:trifle_sub_collection]) : nil
        rescue Trifle::API::FetchError
          nil
        end
      end

      # Helper methods for view
      def value_for(key)
        return '' unless self.param_values && self.param_values[key]
        self.param_values[key]
      end

      def label_for(key)
        return '' unless self.param_values && self.param_values[key]
        id = self.param_values[key]
        case key
        when :trifle_root_collection
          current_root_collection.try(:title).to_s
        when :trifle_sub_collection
          current_sub_collection.try(:title).to_s
        else
          raise 'Unknown key to get label for'
        end
      end

    end
  end
end
