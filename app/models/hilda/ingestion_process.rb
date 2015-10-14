module Hilda
  class IngestionProcess < ActiveFedora::Base
    include Hilda::HydraModuleGraph

#    Bootstrap view generation requires this to work
#    def self.columns
#      []
#    end
  end
end
