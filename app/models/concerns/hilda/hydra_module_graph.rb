module Hilda::HydraModuleGraph
  extend ActiveSupport::Concern

  include Hilda::ModuleGraphBehaviour

  included do
    property :module_graph_serialisation, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/hilda#module_graph_serialisation')

    before_save :serialise_module_graph
    after_find :deserialise_module_graph
  end

  def serialise_module_graph
    self.module_graph_serialisation = to_json
  end

  def deserialise_module_graph
    from_json( module_graph_serialisation )
  end

end
