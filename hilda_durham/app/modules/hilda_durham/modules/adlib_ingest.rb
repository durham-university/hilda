module HildaDurham
  module Modules
    class AdlibIngest
      include Hilda::ModuleBase
      include DurhamRails::Actors::FileCopier
      include DurhamRails::Actors::ShellRunner
      include Hilda::Modules::WithTempFiles

      def image_files
        module_input[:source_files]
      end

      def adlib_record
        raise "TODO"
      end

      def run_module
        output = module_input.deep_dup
        @file_metadata = output[:file_metadata]
        unless validate_record && convert_images && send_to_adlib
          self.run_status = :error
        else
          self.module_output = output.merge(adlib_images: @converted_images)          
        end
      end

      # note that this matches adlib and source images in addition to just validating
      def validate_record
        all_ok = true
        adlib_record.reproductions_full.each do |adlib_file|
          file_key, file = match_adlib_file(adlib_file)
          if !file_key
            all_ok = false
            log!(:error, "Couldn't find a match for adlib file #{adlib_file}")
          else
            log!(:info, "Matched adlib file #{adlib_file} with #{file[:original_filename]}")
            @file_metadata[:"#{file_key}__identifier"] ||= []
            @file_metadata[:"#{file_key}__identifier"] << "adlib_file:#{adlib_file}"
          end
        end

        image_files.select do |file_key, file|
          !(@file_metadata[:"#{file_key}__identifier"].try(:any?) do |id| id.start_with?('adlib_file:') end)
        end .each do |file_key, file|
          all_ok = false
          log!(:error, "couldn't find a match for input file #{file[:original_filename]}")
        end

        all_ok
      end

      def convert_images
        self.log!(:info, "Converting images")
        @converted_images = {}
        image_files.each do |file_key,file|
          file[:adlib_image_path] = nil
          convert_image(file_key, file)
          unless file[:adlib_image_path] && File.exists?(file[:adlib_image_path]) && File.size(file[:adlib_image_path])>0
            log!(:error, "Failed to convert file #{file{:path}}")
            return false 
          end
        end
        true
      end

      def convert_image(key, file_hash)
        source_path = file_hash[:path]
        # touch a temp file to reserve a path for the actual convert command
        temp_path = add_temp_file() do |file| end
        @converted_images[key] = temp_path
        log!(:info, "Converting image #{source_path} to #{temp_path}")
        out, err, status = shell_exec('',*convert_command(source_path, temp_path))
        unless status==0
          log!(:error, "Error (#{status}) converting image #{source_path}")
          log!(:error, out)
          log!(:error, err)
          @converted_images[key] = nil
        end
      end

      def send_to_adlib
        self.log!(:info, "Sending to adlib")
        self.log!(:error, "Not implemented")

        # TODO:
        # Copy converted temp file to where it needs to go.
        # Use Adlib API to send in data, two cases, the record may or may not already exist.
        # Image server location for images is set in Trifle image_deposit_actor. Trifle will
        # also need to interface with Adlib to get that in Adlib. 
        # Maybe best to put Adlib file path in identifiers in Trifle so that images can
        # be matched up later.

        false
      end

      def convert_command(source_path, dest_path)
        ["convert",source_path,"-resize","512x512","-quality","92","jpeg:#{dest_path}"]
      end

      def match_adlib_file(adlib_file)
        adlib_file_norm = normalise_filename(adlib_file.gsub(norm_re,'_'))
        image_files.find do |file_key, file|
          file_norm = normalise_filename(file[:original_filename])
          adlib_file_norm == file_norm
        end
      end

      def normalise_filename(file_name)
        file_name = file_name.split('/').last
        file_name = file_name.split('.')[0..-2].join('.') if file_name.include?('.')
        file_name.gsub(/[\s_-]+/,'_')
      end

    end
  end
end