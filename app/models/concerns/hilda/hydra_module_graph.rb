module Hilda::HydraModuleGraph
  extend ActiveSupport::Concern

  include Hilda::ModuleGraphBehaviour

  included do
    has_subresource "module_graph_serialisation", class_name: 'ActiveFedora::File'
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
    if self.module_graph_serialisation.is_a?(ActiveFedora::LoadableFromJson::SolrBackedMetadataFile)
      from_json({log:{log:[]}, graph_params:{}, modules:[], graph:{}, start_modules:[]}) 
    else
      from_json( self.module_graph_serialisation.content )
    end
  end
  
  def run_status(modules=nil)
    return @solr_run_status if @solr_run_status
    super
  end
  
  def init_with_json(json)
    super(json)
    parsed = JSON.parse(json)
    @solr_run_status = parsed['run_status'].try(:to_sym)
    self
  end
  
  def serializable_hash(*args)
    super(*args).merge({'run_status' => run_status })
  end
    
  def reload(*args)
    super(*args).tap do |obj|
      deserialise_module_graph
    end
  end

  def to_s
    title || id
  end

end
