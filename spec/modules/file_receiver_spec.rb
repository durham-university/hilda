require 'rails_helper'

RSpec.describe Hilda::Modules::FileReceiver do
  let( :image_file1_uploaded ) {
    Rack::Test::UploadedFile.new(File.join(ActionController::TestCase.fixture_path, 'test1.jpg'), 'image/jpeg')
  }
  let( :image_file2_uploaded ) {
    Rack::Test::UploadedFile.new(File.join(ActionController::TestCase.fixture_path, 'test2.jpg'), 'image/jpeg')
  }
  let( :image_file1 ) { fixture('test1.jpg') }
  let( :image_file2 ) { fixture('test2.jpg') }
  let( :image_file1_md5 ) { '15eb7a5c063f0c4cdda6a7310b536ba4' }
  let( :image_file2_md5 ) { '628ad656aba353bdf06edd6e5d25785d' }
  let( :zip_file ) { fixture('test.zip') }
  let( :mod ) {
    graph.add_start_module(Hilda::Modules::FileReceiver).tap do |mod|
      mod.module_output = {}
    end
  }
  let( :graph ) { Hilda::ModuleGraph.new }
  let( :sent_files ) { [image_file1, image_file2] }

  after { mod.remove_temp_files if mod.module_output.try(:[],:temp_files).try(:any?) }

  describe "#file_basename" do
    it "handles Strings" do
      expect(mod.file_basename('/tmp/testfile.zip')).to eql 'testfile.zip'
    end
    it "handles Files" do
      expect(mod.file_basename(image_file1)).to eql 'test1.jpg'
    end
    it "handles uploads" do
      expect(mod.file_basename(image_file1_uploaded)).to eql 'test1.jpg'
    end
  end

  describe "#make_copies_of_files" do
    let( :files ) { [{file: image_file1, md5: 'abc'}, {file: zip_file, md5: 'def'}] }
    let( :new_files ) { mod.make_copies_of_files(files); mod.param_values[:files] }
    let( :files2 ) { [{file: image_file2, md5: 'ghi'}] }
    let( :new_files2 ) { new_files ; mod.make_copies_of_files(files2); mod.param_values[:files] }

    it "copies files" do
      expect(new_files.length).to eql 2
      expect(new_files['test1.jpg'][:original_filename]).to eql 'test1.jpg'
      expect(new_files['test1.jpg'][:path]).to end_with 'test1.jpg'
      expect(new_files['test1.jpg'][:md5]).to eql 'abc'
      expect(new_files['test.zip'][:original_filename]).to eql 'test.zip'
      expect(new_files['test.zip'][:path]).to end_with 'test.zip'
      expect(new_files['test.zip'][:md5]).to eql 'def'
      expect(File.size(new_files['test1.jpg'][:path])).to eql files[0][:file].size
      expect(File.size(new_files['test.zip'][:path])).to eql files[1][:file].size
    end

    it "can append new files" do
      expect(new_files2.length).to eql 3
      expect(new_files['test1.jpg'][:original_filename]).to eql 'test1.jpg'
      expect(new_files['test1.jpg'][:path]).to end_with 'test1.jpg'
      expect(new_files['test1.jpg'][:md5]).to eql 'abc'
      expect(new_files['test2.jpg'][:original_filename]).to eql 'test2.jpg'
      expect(new_files['test2.jpg'][:path]).to end_with 'test2.jpg'
      expect(new_files['test2.jpg'][:md5]).to end_with 'ghi'
      expect(new_files['test.zip'][:original_filename]).to eql 'test.zip'
      expect(new_files['test.zip'][:path]).to end_with 'test.zip'
    end

    it "works without md5s" do
      files[0] = files[0][:file]
      files[1] = files[1][:file]
      expect(new_files.length).to eql 2
      expect(new_files['test1.jpg'][:original_filename]).to eql 'test1.jpg'
      expect(new_files['test.zip'][:original_filename]).to eql 'test.zip'
    end

    it "returns only added files" do
      new_files # add some by referencing
      expect(mod.make_copies_of_files(files2).size).to eql 1
      expect(mod.param_values[:files].size).to eql 3
    end

    it "adds temp files to temp file list" do
      new_files # make by referencing
      expect(mod.param_values[:received_temp_files].length).to eql 3
      new_files2
      expect(mod.param_values[:received_temp_files].length).to eql 4
    end
  end

  describe "#remove_received_file" do
    before {
      mod.param_values[:files] = {
        'test1.jpg' => { path: '/tmp/aaa/test1.jpg', original_filename: 'test1.jpg'},
        'test2.jpg' => { path: '/tmp/aaa/test2.jpg', original_filename: 'test2.jpg'},
      }
      mod.param_values[:received_temp_files] = ['/tmp/aaa/test1.jpg', '/tmp/aaa/test2.jpg']
    }
    it "removes file from values and removes temp files" do
      expect(mod).to receive(:remove_temp_files).with(['/tmp/aaa/test1.jpg'])
      mod.remove_received_file('test1.jpg')
      expect(mod.param_values[:files]).to eql({'test2.jpg' => { path: '/tmp/aaa/test2.jpg', original_filename: 'test2.jpg'}})
    end
  end

  describe "#remove_all_received_files" do
    it "calls remove_received_temp_files" do
      expect(mod).to receive(:remove_received_temp_files)
      mod.remove_all_received_files
    end
    it "resets values" do
      mod.param_values[:files] = { 'test1.jpg' => { path: '/tmp/aaa/test1.jpg', original_filename: 'test1.jpg'} }
      mod.param_values[:received_temp_files] = ['/tmp/aaa/test1.jpg']
      mod.remove_all_received_files
      expect(mod.param_values[:files]).to eql({})
      expect(mod.param_values[:received_temp_files]).to eql []
    end
  end

  describe "#calculate_md5" do
    it "works" do
      expect(mod.calculate_md5(image_file1)).to eql image_file1_md5
    end
  end

  describe "#verify_md5s" do
    before {
      allow(graph.file_service).to receive(:get_file) do |key,&block|
        block.call(image_file1) if key=='1'
        block.call(image_file2) if key=='2'
      end
    }
    it "fails when md5s don't match" do
      errors = mod.verify_md5s({'test1.jpg' => {path: '1', md5: image_file1_md5}, 'test2.jpg' => {path: '2', md5: image_file1_md5}})
      expect(errors).to eql true
      expect(mod.log.errors?).to eql true
    end
    it "passes when everything matches" do
      errors = mod.verify_md5s({'test1.jpg' => {path: '1', md5: image_file1_md5}, 'test2.jpg' => {path: '2', md5: image_file2_md5}})
      expect(errors).to eql false
      expect(mod.log.errors?).to eql false
    end
  end

  describe "#unzip" do
    before {
      allow(graph.file_service).to receive(:get_file).and_call_original
      allow(graph.file_service).to receive(:get_file).with(zip_file.path) do |key,&block|
        block.call(zip_file)
      end
    }
    let( :new_files ) { mod.unzip(zip_file.path) }
    it "unzips file contents" do
      expect(new_files.length).to eql 2
      expect(new_files['test1.jpg'][:original_filename]).to eql 'test1.jpg'
      expect(new_files['test1.jpg'][:path]).to end_with 'test1.jpg'
      expect(new_files['test1.jpg'][:md5]).to eql image_file1_md5
      expect(new_files['test2.jpg'][:original_filename]).to eql 'test2.jpg'
      expect(new_files['test2.jpg'][:path]).to end_with 'test2.jpg'
      expect(new_files['test2.jpg'][:md5]).to eql image_file2_md5
      expect(File.size(new_files['test1.jpg'][:path])).to eql image_file1.size
      expect(File.size(new_files['test2.jpg'][:path])).to eql image_file2.size
    end

    it "adds temp files to temp file list" do
      new_files # make by referencing
      expect(mod.param_values[:temp_files].length).to eql 3
    end

    it "works with StringIO" do
      allow(graph.file_service).to receive(:get_file).with('1') do |key,&block|
        block.call(StringIO.new(zip_file.read))
      end
      expect(mod.unzip('1').length).to eql 2
    end
  end

  describe "#unpack_files" do
    before {
      allow(graph.file_service).to receive(:get_file) do |key,&block|
        block.call(image_file1) if key==image_file1.path
        block.call(zip_file) if key==zip_file.path
      end
    }

    let( :files ) { {
      'test1.jpg' => { path: image_file1.path, original_filename: 'test1.jpg' },
      'test.zip' => { path: zip_file.path, original_filename: 'test.zip' },
    } }
    let( :new_files ) { new_files = mod.unpack_files(files) }
    it "adds unpacked files to file list" do
      expect(new_files.length).to eql 3
      expect(new_files['test1.jpg'][:original_filename]).to eql 'test1.jpg'
      expect(new_files['test1.jpg'][:path]).to end_with 'test1.jpg'
      expect(new_files['test1.jpg_2'][:original_filename]).to eql 'test1.jpg'
      expect(new_files['test1.jpg_2'][:path]).to end_with 'test1.jpg'
      expect(new_files['test2.jpg'][:original_filename]).to eql 'test2.jpg'
      expect(new_files['test2.jpg'][:path]).to end_with 'test2.jpg'
    end
    it "adds temp files to temp file list" do
      new_files # make by referencing
      expect(mod.param_values[:temp_files].length).to eql 3
    end
  end

  describe "#run_module" do
    let(:file_copies) { {
      'test1.jpg' => { path: '/tmp/aaa/test1.jpg', original_filename: 'test1.jpg', md5: image_file1_md5 },
      'test2.jpg' => { path: '/tmp/aaa/test2.jpg', original_filename: 'test2.jpg', md5: image_file2_md5 }
    } }
    before {
      mod.param_values[:files] = file_copies
    }
    it "calls essential functions" do
      expect(mod).to receive(:unpack_files).with(file_copies).and_return(file_copies)
      expect(mod).to receive(:verify_md5s).with(file_copies).and_return(false)
      mod.run_module
      expect(mod.module_output[:source_files]).to eql file_copies
    end
    it "sets error status when md5 verification fails" do
      expect(mod).to receive(:verify_md5s).with(file_copies).and_return(true)
      mod.run_module
      expect(mod.run_status).to eql :error
    end
  end

  describe "#receive_params" do
    let(:params){ {files: [image_file1_uploaded], md5s: [image_file1_md5]} }
    it "makes copies of received files" do
      expect(mod).to receive(:make_copies_of_files).with([{file: image_file1_uploaded, md5: image_file1_md5}])
      mod.receive_params(params)
    end
    it "works with files hash" do
      expect(mod).to receive(:make_copies_of_files).with([{file: image_file1_uploaded, md5: nil}, {file: image_file2_uploaded, md5: nil}])
      mod.receive_params({ files: {
          '0' => image_file1_uploaded,
          '1' => image_file2_uploaded
        } })
    end
    it "sets param values" do
      mod.receive_params(params)
      expect(mod.param_values[:files]).to be_a Hash
      expect(mod.param_values[:files].size).to eql 1
    end
    it "adds received temporary files to their own index" do
      mod.receive_params(params)
      expect(mod.param_values[:received_temp_files]).to be_a Array
      expect(mod.param_values[:received_temp_files].size).to eql 2
      expect(mod.param_values[:temp_dir]).to be_present
      expect(mod.module_output[:temp_files]).to eql nil
    end
  end

  describe "#cleanup" do
    it "removes received temporary files" do
      expect(mod).to receive(:remove_received_temp_files)
      mod.cleanup
    end
  end

  describe "#reset_module" do
    it "doesn't remove received temporary files" do
      mod.param_values[:received_temp_files] = ['/tmp/aaa']
      expect(mod).to receive(:remove_temp_files).with(no_args)
      mod.reset_module
      expect(mod.param_values[:received_temp_files]).not_to be_empty
    end
  end

  describe "#remove_received_temp_files" do
    it "removes received temp files" do
      mod.param_values[:received_temp_files] = ['/tmp/aaa']
      expect(mod).to receive(:remove_temp_files).with(['/tmp/aaa'])
      mod.remove_received_temp_files
      expect(mod.param_values[:received_temp_files]).to be_empty
    end
  end

end
