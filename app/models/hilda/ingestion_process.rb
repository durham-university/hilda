module Hilda
  class IngestionProcess < ActiveFedora::Base
    include Hilda::HydraModuleGraph
    include Hilda::ModuleGraphAutosave
    include Hilda::BackgroundRunnable
    include DurhamRails::WithFedoraFileService

    property :owner, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/hilda#owner')

#    Bootstrap view generation requires this to work
#    def self.columns
#      []
#    end
  end
end
