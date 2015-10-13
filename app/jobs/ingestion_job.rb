module Hilda
  class IngestionJob
    include Hilda::JobBase
    include Hilda::Jobs::WithResource
    include Hilda::Jobs::WithUser

    def run_job

    end
  end
end
