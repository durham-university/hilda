module Hilda
  class IngestionProcessTemplate < ActiveFedora::Base
    include Hilda::HydraModuleGraph
    property :description, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/hilda#template_description')
    property :template_key, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/hilda#template_key') do |index|
      index.as :stored_searchable
    end
    property :order_hint, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/hilda#order_hint')

    def build_process
      Hilda::IngestionProcess.new.tap do |p|
        p.from_json( self.module_graph_serialisation.content )
        p.title = "#{self.title || self.template_key || 'Process'} #{DateTime.now.to_formatted_s}"
      end
    end
    
    def clone(title, key, description, exists_behaviour=:clean)
      self.class.new_template(title, key, description, exists_behaviour) do |template|
        template.from_json( self.module_graph_serialisation.content )
        template.title = title 
        template.template_key = key 
        template.description = description
        yield template
      end
    end

    def to_s
      title || template_key || id
    end

    def self.new_template(title, key, description, exists_behaviour=:clean)
      raise 'template key is required' unless key.present?
      existing = Hilda::IngestionProcessTemplate.where(template_key: key)
      raise 'Template already exists' if exists_behaviour==:error && existing.any?
      return existing.first if exists_behaviour==:skip && existing.any?

      order_hint = nil
      order_hint = existing.first.order_hint if existing.any?

      raise 'Unknown exists_behaviour' unless exists_behaviour==:clean
      existing.delete_all if existing.any?

      unless order_hint
        order_hint = Hilda::IngestionProcessTemplate.all.to_a.map do |t| t.order_hint.to_i end .max || 0
      end

      template = Hilda::IngestionProcessTemplate.new(title: title, template_key: key, description: description, order_hint: order_hint)
      yield template
      template.save
      template
    end
  end
end
