module Hilda::BackgroundRunnable
  extend ActiveSupport::Concern

  included do
    property :background_job_id, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/hilda#background_job_id')
  end

  def start_background_job(job)
    self.background_job_id = job.id
    save!
  end

  def background_job_running?
    self.background_job_id.present?
  end
  def background_job_finished(job,status=nil)
    self.background_job_id = ''
    save!
  end

end
