module Hilda::Jobs::WithFiles
  extend ActiveSupport::Concern

  included do
    attr_accessor :file_paths
  end

  def initialize(*args)
    super
    @file_paths={}
    @file_table={}
  end

  def set_file(file_io)
    add_file(:default,file_io)
  end

  def add_file(file_ref,file_io)
    @file_table[file_ref]=file_io
  end

  def get_file(file_ref=:default)
    @file_table[file_ref]
  end

  def dump_attributes
    super + [:file_paths]
  end

  def marshal_dump
    store_files
    super
  end

  def marshal_load(obj)
    super
    load_files
  end

  def temp_dir
    Hilda.config['job_temp_dir'] || Dir.tmpdir || raise('Job temp dir not specified in Schmit config')
  end

  def validate_job!
    super
    @file_table.values.each do |f|
      raise 'Invalid file' if !f.respond_to?(:read)
    end
  end

  def job_finished
    remove_files
    super
  end

  private
    def make_temp_file_path
      loop do
        path = File.join(temp_dir,SecureRandom.hex)
        break path unless File.exists?(path)
      end
    end

    def store_files
      @file_paths = @file_table.each_with_object({}) do |(k,v),o|
        if @file_paths.key? k
          # don't save the file again if it's already been saved, this happens
          # when job is marshalled more than once
          o[k] = @file_paths[k]
          next
        end
        o[k] = make_temp_file_path
        file = File.open(o[k],'wb')
        IO.copy_stream( @file_table[k], file )
        file.close
      end
    end

    def load_files
      @file_table = file_paths.each_with_object({}) do |(k,v),o|
        o[k]=File.new(v)
      end
    end

    def remove_files
      @file_table.values.each do |file|
        next if !file.path.start_with? temp_dir
        File.unlink(file)
      end
    end

end
