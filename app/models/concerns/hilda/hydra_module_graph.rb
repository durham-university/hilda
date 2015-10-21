module Hilda::HydraModuleGraph
  extend ActiveSupport::Concern

  include Hilda::ModuleGraphBehaviour

  included do
    contains "module_graph_serialisation", class_name: 'ActiveFedora::File'
#    property :module_graph_serialisation, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/hilda#module_graph_serialisation')
    property :background_job_id, multiple: false, predicate: ::RDF::URI.new('http://collections.durham.ac.uk/ns/hilda#background_job_id')

    before_save :serialise_module_graph
    after_find :deserialise_module_graph
    after_find :set_last_saved
    after_save :set_last_saved
    before_destroy :cleanup

    attr_accessor :last_saved
  end

  def serialise_module_graph
#    chunk_size = 2000
#    json = to_json
#    raise 'serialisation too big, unable to save' if json.length > chunk_size*1000
#    chunks = json.scan(/.{1,#{chunk_size}}/).map.with_index do |chunk,i|
#      "#{sprintf('%03d',i)}#{chunk}"
#    end
#    self.module_graph_serialisation = chunks
    self.module_graph_serialisation ||= ActiveFedora::File.new
    self.module_graph_serialisation.content = to_json
  end

  def deserialise_module_graph
#    chunks = module_graph_serialisation.to_a.sort do |a,b|
#      a[0..2] <=> b[0..2]
#    end
#    json = (chunks.map do |c| c[3..-1] end).join
#    from_json( json )
    from_json( self.module_graph_serialisation.content )
  end

  def module_finished(mod,execute_next=true)
    autosave # this has to be before super, otherwise the whole graph is executed before autosave
    super
  end

  def module_starting(mod)
    super
    autosave
  end

  def graph_stopped
    super
    autosave
  end

  def graph_finished
    super
    autosave
  end

  def autosave
    save if change_time > last_saved
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

  private

    def set_last_saved
      self.last_saved = change_time
    end

end
