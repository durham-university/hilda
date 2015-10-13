module Hilda::Modules
  class FileReceiver
    include Hilda::ModuleBase
    include Hilda::Modules::WithTempFiles

    def file_basename(file)
      return File.basename(file) if file.is_a?(String) || file.is_a?(File)
      return file.original_filename if file.respond_to?(:original_filename)
      return nil
    end

    def make_copies_of_files(files)
      dir = make_temp_file_path
      Dir.mkdir(dir)
      add_temp_file(dir)

      return files.map do |file|
        basename = file_basename(file)
        if basename
          file_path = File.join(dir,sanitise_filename(basename))
        else
          file_path = make_temp_file_path(dir)
        end
        raise 'Temporary file already exists' if File.exists?(file_path)

        out = File.open(file_path,'wb')
        IO.copy_stream(file, out)
        out.close
        add_temp_file file_path
        file_path
      end
    end

    def unzip(file)
      file_list = []
      dir = make_temp_file_path
      Dir.mkdir(dir)
      add_temp_file(dir)

      Zip::File.open(file) do |zip_file|
        zip_file.each do |entry|
          dest = File.join(dir,File.basename(entry.name))
          entry.extract(dest)
          add_temp_file(dest)
          file_list << dest
        end
      end
      file_list
    end

    def unpack_files(files)
      return (files.map do |file|
        if File.extname(file).downcase == '.zip'
          unzip(file)
        else
          file
        end
      end).flatten
    end

    def run_module
      files = module_graph[:sent_files]
      files = make_copies_of_files(files) if module_graph.fetch(:copy_files, true)
      files = unpack_files(files) if module_graph.fetch(:unpack_files, true)
      module_output.merge!({ source_files: files })
    end

  end
end
