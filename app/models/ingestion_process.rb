module Hilda
  class IngestionProcess < ActiveFedora::Base
    property :module_params, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/hilda#module_params')

    before_save :serialise_module_params
    after_find :deserialise_module_params

    def initialize
      module_params = {}
    end

    def get_module_params(mod)
      module_params[mod]
    end
    
    def serialise_module_params
    end

    def deserialise_module_params
    end

  end
end
