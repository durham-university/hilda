module Hilda::Modules
  class FileSelector
    include Hilda::ModuleBase
    include Hilda::Modules::WithParams
    
    def initialize(*args)
      super(*args)
      self.param_defs = { files: { name: 'files', type: :file, default: nil } }
      self.param_values.merge!({form_template: 'hilda/modules/file_select'})
    end
    
    def receive_params(params)
      raise "Module cannot receive params in current state" unless can_receive_params?
      if params.key?(:deselect_all)
        set_selected_files([])
        file_names_changed!
        check_submitted_status!
        changed!
      end
      if params.key?(:select_files)
        set_selected_files(params_array(params[:select_files]))
        file_names_changed!
        check_submitted_status!
        changed!
      end
      return true
    end
    
    def set_selected_files(files)
      self.param_values ||= {}
      self.param_values[:files] = {}
      self.param_values[:file_names] = []
      @selected_hash = nil
      
      files.each do |file|
        file_path = resolve_file(file)
        next unless file_path.present?
        file_name = File.basename(file)
        self.param_values[:files][file_name] = {logical_path: file, path: file_path, original_filename: file_name}
        self.param_values[:file_names] << file_name
      end
    end
    
    def file_names_changed!
      self.module_graph[:source_file_names] = param_values[:file_names]
      self.module_graph.graph_params_changed
    end

    def calculate_md5(readable)
      digest = Digest::MD5.new
      buf = ""
      while readable.read(16384, buf)
        digest.update(buf)
      end
      digest.hexdigest
    end
    
    def calculate_md5s
      (self.param_values[:files] || {}).values.each do |file|
        File.open(file[:path]) do |open_file|
          file[:md5] = calculate_md5(open_file)
        end
      end
    end
    
    def run_module
      unless all_params_valid?
        log! :error, 'Submitted values are not valid, cannot proceed.'
        self.run_status = :error
        return
      end

      files = param_values[:files]
      log!(:info, "Selected #{files.length} files")
      
      log!(:info, "Calculating MD5s")
      calculate_md5s
      
      files.each do |key,file|
        log! :info, "- #{file[:original_filename]} (md5:#{file[:md5]})"
      end
      module_output.merge!({ source_files: files })
    end
    
    def get_file_list(path=nil)
      path ||= ''
      path = resolve_file(path)
      return [] unless path
      re = /^#{root_path}/
      tree = {
        name: '/',
        path: '/',
        type: 'dir',
        children: {},
        selected: false
      }
      cache = param_values[:file_list_cache]
      if cache.nil?
        self.param_values[:file_list_cache] = {}
        cache = param_values[:file_list_cache]
        changed!
      end
      Dir[File.join(root_path,'**','*')].each do |local_path| 
        next unless match_filter(local_path)
        stat = cache[local_path]
        unless stat.present?
          stat = File.stat(local_path)
          stat = { 
            file?: stat.file?,
            size: stat.size,
            mtime: stat.mtime.to_s
          }
          cache[local_path] = stat
          changed!
        end
        next unless stat[:file?]
        
        path = local_path.split(re)[1] # remove root_path
        path = File.split(path) # split to path components
        folder = path[0..-2].inject(tree) do |folder, path_part| 
          next folder if path_part == '.' # File.split('moo.txt') returns ['.','moo.txt']
          folder[:children][path_part] ||= {
            name: path_part,
            path: File.join(folder[:path], path_part),
            type: 'dir',
            children: {}
          }
        end
        folder[:children][path.last] = {
          name: path.last,
          path: File.join(folder[:path], path.last),
          type: 'file',
          size: stat[:size],
          mtime: stat[:mtime],
          selected: file_selected?(File.join(folder[:path], path.last))
        }
      end
      
      select_folders = lambda do |node|
        all_selected = true
        node[:children].values.each do |child|
          select_folders.call(child) if child[:type] == 'dir'
          all_selected &&= child[:selected]
        end
        node[:selected] = all_selected
      end
      select_folders.call(tree)
      
      tree
    end
    
    def file_selected?(path)
      @selected_hash ||= begin
        (param_values[:files] || {}).values.each_with_object({}) do |f,hash| 
          hash[f[:logical_path]] = true if f[:logical_path].present?
        end
      end
      @selected_hash.key?(path)
    end
    
    def validate_param(key,value)
      return super unless key == :files
      value.values.each do |file|
        return false unless File.file?(file[:path])
      end
      true
    end    
    
    private
    
      def filter_re
        @filter_re ||= begin
          pattern = param_values[:filter_re]
          pattern.present? ? Regexp.compile(pattern) : nil
        end
      end
      
      def match_filter(path)
        return true unless filter_re.present?
        !!(filter_re.match(path))
      end

      def params_array(params)
        if params.is_a? Hash
          params.each_with_object([]) do |(key,value),obj| obj << [key,value] end \
              .sort do |a,b| a[0].to_i <=> b[0].to_i end \
              .map do |a| a[1] end
        elsif params.is_a? Array
          # Do not use just Array(params), it causes problems with files
          params
        else
          [params]
        end
      end
      
      def root_path
        @root_path ||= begin
          path = File.absolute_path(param_values[:root_path])
          path += File::SEPARATOR unless path.ends_with?(File::SEPARATOR)
        end
      end
      
      def resolve_file(file)
        return root_path if file == '' || file == File::SEPARATOR
        path = File.absolute_path(File.join(root_path,file))
        return nil unless path.starts_with?(root_path) && match_filter(path)
        path
      end
    
  end
end