module Hilda::HydraModuleGraph
  extend ActiveSupport::Concern

  include Hilda::ModuleGraphBehaviour

  included do
    contains "module_graph_serialisation", class_name: 'ActiveFedora::File'
    property :title, multiple: false, predicate: ::RDF::Vocab::DC.title

    before_save :serialise_module_graph
    after_find :deserialise_module_graph
    before_destroy :cleanup
  end

  def serialise_module_graph
    self.module_graph_serialisation ||= ActiveFedora::File.new
    self.module_graph_serialisation.content = to_json
  end

  def deserialise_module_graph
    from_json( self.module_graph_serialisation.content )
  end

  def to_s
    title || id
  end

end
