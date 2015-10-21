module Hilda::Jobs::WithResource
  extend ActiveSupport::Concern

  included do
    attr_accessor :resource_id
  end

  def initialize(params={})
    super(params)
    case params[:resource]
    when String
      @resource = nil
      self.resource_id = params[:resource]
    else
      @resource = params[:resource]
      self.resource_id = resource.id
    end
  end

  def dump_attributes
    super + [:resource_id]
  end

  def resource
    @resource ||= ActiveFedora::Base.find(resource_id)
  end

  def validate_job!
    super
    raise "Resource doesn't implement background jobs" if !resource.respond_to?(:background_job_running?)
    raise "Resource is already processing a background job" if resource.background_job_running?
  end

  def pushing_job
    super
    resource.start_background_job(self)
  end

  def job_finished
    ok = resource.background_job_finished(self)
    raise 'Unable to mark job finished in Fedora' unless ok
    super
  end
end
