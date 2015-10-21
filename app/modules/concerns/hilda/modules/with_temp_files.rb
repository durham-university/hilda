module Hilda::Modules
  module WithTempFiles
    extend ActiveSupport::Concern

    def add_temp_file(file, index=nil)
      index ||= ( module_output[:temp_files] ||= [] )
      index << file
    end

    def temp_dir
      module_graph.fetch(:temp_dir,Dir.tmpdir) || raise('Couldn\'t resolve temp dir')
    end

    def make_temp_file_path(dir=nil)
      dir ||= temp_dir
      loop do
        path = File.join(dir,SecureRandom.hex)
        break path unless File.exists?(path)
      end
    end

    def sanitise_filename(file_name)
      file_name.gsub(/(\.\.)|[^a-zA-Z0-9_.]/,'_')
    end

    def reset_module(*args)
      remove_temp_files
      self.module_output.try(:[]=,:temp_files,[])
      return super(*args)
    end

    def cleanup(*args)
      remove_temp_files
      return super(*args)
    end

    def remove_temp_files(files=nil)
      files ||= self.module_output.try(:[],:temp_files) || []
      # Go in reverse order so that directories are removed after contents
      files.reverse.each do |file|
        if !file.start_with? temp_dir
          log! :warning, "Not removing temp file \"#{file}\". It's not under temp dir \"#{temp_dir}\""
        elsif File.exists?(file)
          if File.directory?(file)
            begin
              Dir.unlink(file)
            rescue e
              log! "Unable to delete temp directory \"#{file}\"", e
            end
          else
            begin
              File.unlink(file)
            rescue e
              log! "Unable to delete temp file \"#{file}\"", e
            end
          end
        end
      end
    end

  end
end
