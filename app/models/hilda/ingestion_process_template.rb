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

    def to_s
      title || template_key || id
    end
  end
end
