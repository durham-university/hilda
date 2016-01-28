module HildaDurham
  module Modules
    class SchmitLinker
      include Hilda::ModuleBase
      include Hilda::Modules::WithParams

      def initialize(module_graph, param_values={})
        super(module_graph, param_values)
        self.param_values.merge!({form_template: 'hilda_durham/modules/schmit_linker_form'})
        self.param_defs = {}
        self.param_defs[:schmit_repository] = {
            name: 'repository',
            type: :string
          }
        self.param_defs[:schmit_fonds] = {
            name: 'fonds',
            type: :string
          } if include_fonds?
        self.param_defs[:schmit_catalogue] = {
            name: 'catalogue',
            type: :string
          } if include_catalogue?
      end

      def include_fonds?
        !param_values.fetch(:no_fonds, false)
      end
      def include_catalogue?
        !param_values.fetch(:no_catalogue, false)
      end

      def query_module(params)
        query = params[:schmit_query].try(:downcase) || ''
        cls = nil
        case params[:schmit_type].to_sym
        when :repository
          cls = Schmit::API::Repository
        when :fonds
          cls = Schmit::API::Fonds
        when :catalogue
          cls = Schmit::API::Catalogue
        else
          return { status: 'ERROR', error_message: 'invalid query type' }
        end

        begin
          if cls == Schmit::API::Fonds || cls == Schmit::API::Catalogue
            repo_id = params[:schmit_repository]
            repository = Schmit::API::Repository.find(repo_id)
            res = cls.all_in(repository)
          else
            res = cls.all
          end
        rescue Schmit::API::FetchError => e
          return { status: 'ERROR', error_message: "Unable to get objects. #{e.message}"}
        end

        if cls == Schmit::API::Catalogue && include_fonds?
          fonds_id = params[:schmit_fonds]
          if fonds_id
            res.select! do |obj|
              obj.parent_id == fonds_id
            end
          else
            res = []
          end
        end

        res.select! do |obj|
          obj.title.try(:index,query)
        end if query.present?

        return {
          status: 'OK',
          result: res.map do |obj|
                    obj.as_json.slice(:id,:title).merge({ead_id: obj.ead_id})
                  end .sort do |a,b|
                    a[:title] <=> b[:title]
                  end
        }
      end

      def validate_reference
        begin
          repository = current_repository
          fonds = include_fonds? ? current_fonds : nil
          catalogue = include_catalogue? ? current_catalogue : nil

          return false unless repository
          return false if include_fonds? && !fonds
          return false if include_catalogue? && !catalogue

          return false if catalogue && fonds && !fonds.catalogues.map(&:id).include?(catalogue.id)

          return false if fonds && find_repository(fonds).try(:id) != repository.id
          return false if catalogue && find_repository(catalogue).try(:id) != repository.id

          return true
        rescue Schmit::API::FetchError => e
          return false
        end
      end

      def autorun?
        ready_to_run?
      end

      def run_module
        unless all_params_valid?
          log! :error, 'Schmit link not yet submitted, cannot proceed.'
          self.run_status = :error
          return
        end

        unless validate_reference
          log! :error, 'Invalid reference'
          self.run_status = :error
          return
        end

        self.module_output = module_input.deep_dup.merge({
          schmit_link: param_values.slice(*self.param_defs.keys)
        })
      end

      def current_repository
        @current_repository ||= begin
          (self.param_values && self.param_values[:schmit_repository]) ? Schmit::API::Repository.find(self.param_values[:schmit_repository]) : nil
        rescue Schmit::API::FetchError
          nil
        end
      end

      def current_fonds
        @current_fonds ||= begin
          (self.param_values && self.param_values[:schmit_fonds]) ? Schmit::API::Fonds.find(self.param_values[:schmit_fonds]) : nil
        rescue Schmit::API::FetchError
          nil
        end
      end

      def current_catalogue
        @current_catalogue ||= begin
          (self.param_values && self.param_values[:schmit_catalogue]) ? Schmit::API::Catalogue.find(self.param_values[:schmit_catalogue]) : nil
        rescue Schmit::API::FetchError
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
        when :schmit_repository
          current_repository.try(:title).to_s
        when :schmit_fonds
          current_fonds.try(:title).to_s
        when :schmit_catalogue
          current_catalogue.try(:title).to_s
        else
          raise 'Unknown key to get label for'
        end
      end

      private

        def find_repository(obj)
          return nil if obj.nil?
          return obj if obj.is_a? Schmit::API::Repository
          find_repository(obj.parent)
        end

    end
  end
end
