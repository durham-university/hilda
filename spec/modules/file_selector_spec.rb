require 'rails_helper'

RSpec.describe Hilda::Modules::FileSelector do
  
  let( :root_path ) { '/tmp/root_path_test' }
  let( :mod ) {
    graph.add_start_module(Hilda::Modules::FileSelector, root_path: root_path).tap do |mod|
      mod.module_output = {}
    end
  }
  let( :graph ) { Hilda::ModuleGraph.new }

  
  describe "#receive_params" do
    it "selects files" do
      expect(mod).to receive(:set_selected_files).with(['test.jpg','moo/baa.zip'])
      expect(mod).to receive(:file_names_changed!)
      mod.receive_params(select_files: ['test.jpg','moo/baa.zip'])      
    end
    it "deselects all file" do
      expect(mod).to receive(:set_selected_files).with([])
      expect(mod).to receive(:file_names_changed!)
      mod.receive_params(deselect_all: 1)
    end
  end
    
  describe "#set_selected_files" do
    let(:new_files) { ['moo.jpg','baa/test.zip'] }
    it "resolves files and sets them" do
      mod.param_values ||= {}
      mod.param_values[:files]={old_file: {}}
      mod.param_values[:file_names] = ['old_file']
      expect(mod).to receive(:resolve_file).twice.and_call_original
      mod.set_selected_files(new_files)
      expect(mod.param_values[:files].count).to eql(2)
      expect(mod.param_values[:files]['moo.jpg']).to eql({path: "#{root_path}/moo.jpg", original_filename: 'moo.jpg', logical_path: 'moo.jpg'})
      expect(mod.param_values[:files]['test.zip']).to eql({path: "#{root_path}/baa/test.zip", original_filename: 'test.zip', logical_path: 'baa/test.zip'})
      expect(mod.param_values[:file_names]).to eql(['moo.jpg','test.zip'])
    end
  end
  
  describe "#file_names_changed!" do
    let(:file_names) { ['test1.jpg','test2.jpg'] }
    before { mod.param_values[:file_names] = file_names }
    it "copies file_names to graph params" do
      expect(graph).to receive(:graph_params_changed)
      mod.file_names_changed!
      expect(graph.graph_params[:source_file_names]).to eql(file_names)
    end
  end
  
  describe "#calculate_md5" do
    let(:readable) { StringIO.new('testtesttest') }
    let(:md5) { 
      digest = Digest::MD5.new
      digest.update("testtesttest")
      digest.hexdigest
    }
    it "calculates md5" do
      expect(mod.send(:calculate_md5, readable)).to eql(md5)
    end
  end
  
  describe "#calculate_md5s" do
    let(:file1) {
      file = Tempfile.new('file_selector_temp')
      file.write('test1')
      file.close
      file.path      
    }
    let(:file2) { 
      file = Tempfile.new('file_selector_temp')
      file.write('test2')
      file.close
      file.path
    }
    after {
      File.unlink(file1)
      File.unlink(file2)
    }
    
    it "calculates md5 of all selected files" do
      mod.param_values[:files] = {'test1'=>{path: file1}, 'test2'=>{path: file2}}
      mod.calculate_md5s
      expect(mod.param_values[:files]['test1'][:md5]).to be_present
      expect(mod.param_values[:files]['test2'][:md5]).to be_present
      expect(mod.param_values[:files]['test1'][:md5]).not_to eql(mod.param_values[:files]['test2'][:md5])
    end
  end
  
  describe "#run_module" do
    let(:files){
      {
        'test1'=>{path: 'test1', original_file: 'test1', md5: '123'}, 
        'test2'=>{path: 'test2', original_file: 'test2', md5: '456'} 
      }
    }
    before { mod.param_values[:files] = files }
    it "cals essential functions and outputs files" do
      expect(mod).to receive(:all_params_valid?).and_return(true)
      expect(mod).to receive(:calculate_md5s)
      expect(mod).to receive(:sort_files).and_call_original
      mod.run_module
      expect(mod.module_output[:source_files]).to eql(files)
    end
  end
  
  describe "#sort_files" do
    let(:files) { double('file list') }
    let(:sorted) { double('sorted list') }
    let(:sorter) { "TestSorter" }
    before {
      class TestSorter
        def self.sort(files) ; end
      end
    }
    after {
      Object.send(:remove_const, :TestSorter)
    }
    it "uses a sorter when defined" do
      mod.param_values[:file_sorter] = sorter
      expect(TestSorter).to receive(:sort).with(files).and_return(sorted)
      expect(mod.send(:sort_files, files)).to eql(sorted)
    end
    it "returns the same list if no sorter defined" do
      expect(mod.send(:sort_files, files)).to eql(files)
    end
  end
  
  describe "#get_file_list" do
    let(:root_path) { File.join(Dir.tmpdir,'file_selector_test')}
    let(:sub_dir) { File.join(root_path,'subdir')}
    let(:file1) { File.join(root_path,'file1.txt').tap do |path| File.open(path,'wb') do |file| file.write('testtest') end end }
    let(:file2) { File.join(root_path,'file2.txt').tap do |path| File.open(path,'wb') do |file| file.write('testtesttest') end end }
    let(:file3) { File.join(sub_dir,'file3.txt').tap do |path| File.open(path,'wb') do |file| file.write('testtesttesttest') end end }
    before {
      Dir.mkdir(root_path)
      Dir.mkdir(sub_dir)
    }
    after {
      File.unlink(file3)
      Dir.rmdir(sub_dir)
      File.unlink(file2)
      File.unlink(file1)
      Dir.rmdir(root_path)
    }
    let(:expected_list){
      {
        name: '/',
        path: '/',
        type: 'dir',
        selected: false,
        children: {
          'subdir' => {
            name: 'subdir',
            path: '/subdir',
            type: 'dir',
            selected: true,
            children: {
              'file3.txt' => { name: 'file3.txt', path: '/subdir/file3.txt', type: 'file', size: 16, selected: true, mtime: File.mtime(file3).to_s }
            }
          },
          'file1.txt' => { name: 'file1.txt', path: '/file1.txt', type: 'file', size: 8, selected: false, mtime: File.mtime(file1).to_s },
          'file2.txt' => { name: 'file2.txt', path: '/file2.txt', type: 'file', size: 12, selected: false, mtime: File.mtime(file2).to_s }
        }
      }      
    }
    it "returns a files hash" do
      file1 ; file2 ; file3 # create by referencing
      mod.param_values[:files] = {'file3.txt' => {logical_path: '/subdir/file3.txt'}}
      expect(File).to receive(:stat).exactly(4).times.and_call_original
      expect(mod.get_file_list).to eql(expected_list)
    end
    it "filters using match_filter" do
      mod.param_values[:filter_re] = '^.*file[13].txt$'
      expect(mod).to receive(:match_filter).exactly(4).times.and_call_original
      file1 ; file2 ; file3 # create by referencing
      files = mod.get_file_list
      expect(files[:children].keys).to match_array(['subdir','file1.txt'])
    end
    it "caches file stats" do
      file1 ; file2 ; file3 # create by referencing
      mod.param_values[:files] = {'file3.txt' => {logical_path: '/subdir/file3.txt'}}
      expect(File).to receive(:stat).exactly(4).times.and_call_original
      change_time = mod.change_time
      expect(mod.get_file_list).to eql(expected_list) # called 4 times in this
      expect(mod.change_time).to be > change_time
      expect(mod.param_values[:file_list_cache][file1]).to be_present
      change_time = mod.change_time
      expect(mod.get_file_list).to eql(expected_list) # 0 times in this
      expect(mod.change_time).to eql(change_time)
    end
  end
  
  describe "#root_path" do
    it "returns path from config and appends / at the end" do
      expect(root_path).not_to end_with('/')
      expect(mod.send(:root_path)).to eql("#{root_path}/")
    end
  end
  
  describe "#resolve_file" do
    before { expect(mod).to receive(:root_path).at_least(:once).and_return(root_path) }
    
    it "maps to real path" do
      expect(mod.send(:resolve_file, 'test/moo.jpg')).to eql(File.join(root_path,'test/moo.jpg'))
    end
    
    it "doesn't return anything outside mounted path" do
      expect(mod.send(:resolve_file, '../test.jpg')).to be_nil
    end

    it "filters using match_filter" do
      mod.param_values[:filter_re] = '^.*file[13].txt$'
      expect(mod).to receive(:match_filter).exactly(3).times.and_call_original
      expect(mod.send(:resolve_file, 'file1.txt')).to eql(File.join(root_path,'file1.txt'))
      expect(mod.send(:resolve_file, 'file2.txt')).to be_nil
      expect(mod.send(:resolve_file, 'file3.txt')).to eql(File.join(root_path,'file3.txt'))
    end    
  end
  
  describe "#file_selected?" do
    before {
      mod.param_values[:files] = {'file1.txt'=>{logical_path: '/file1.txt'}, 'file3.txt'=>{logical_path: '/subdir/file3.txt'}}
    }
    it "checks if file is selected" do
      expect(mod.file_selected?('/file1.txt')).to eql(true)
      expect(mod.file_selected?('/file2.txt')).to eql(false)
      expect(mod.file_selected?('/subdir/file3.txt')).to eql(true)
    end
    it "works after changed to selection" do
      allow(mod).to receive(:resolve_file).and_return('dummy')
      expect(mod.file_selected?('/file1.txt')).to eql(true)
      expect(mod.file_selected?('/file2.txt')).to eql(false)
      mod.set_selected_files(['/file1.txt','/file2.txt'])
      expect(mod.file_selected?('/file1.txt')).to eql(true)
      expect(mod.file_selected?('/file2.txt')).to eql(true)
    end
  end
  
  describe "#validate_param" do
    let(:tempfile) { Tempfile.new('selector_temp').tap do |file| file.close end .path }
    after { File.unlink(tempfile) }
    it "checks files exist" do
      expect(mod.validate_param(:files,{'test'=>{path:tempfile}})).to eql(true)
      expect(mod.validate_param(:files,{'test'=>{path:'/tmp/doesnt_exist'}})).to eql(false)
    end
  end

end