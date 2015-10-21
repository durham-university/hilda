module Hilda::Jobs::JobBase
  extend ActiveSupport::Concern

  included do
    attr_accessor :id
  end

  def initialize(params={})
    self.id = SecureRandom.hex

    @log = Hilda::Log.new
  end

  def log
    @log
  end

  delegate :log!, :errors?, to: :log

  def dump_attributes
    [:id]
  end

  def marshal_dump
    dump_attributes.each_with_object({}) do |attribute,o|
      o[attribute]=self.send(attribute)
    end
  end

  def marshal_load(hash)
    hash.each do |k,v|
      self.send(:"#{k}=",v)
    end
    @log = Hilda::Log.new
  end

  def validate_job!
  end

  def pushing_job
  end

  def queue_job
    validate_job!
    pushing_job
    Hilda.queue.push(self)
    return true
  end

  def run_job
    raise("Implement run_job")
  end

  def run
    begin
      run_job
    rescue StandardError => e
      log! e
    ensure
      job_finished
    end
  end

  def job_finished
  end

end
