RSpec.shared_examples "file service" do
  let( :test_file1 ) { fixture('test1.jpg') }
  let( :test_file2 ) { fixture('test2.jpg') }
  let( :test_file2_path ) { File.join(fixture_path,'test2.jpg') }
  let( :graph ) { Hilda::ModuleGraph.new }
  let( :file_service ) { described_class.new(graph) }

  let( :created_files ) { [] }
  after {
    created_files.reverse.each do |file|
      begin
        file_service.remove_file(file)
      rescue StandardError => e
      end
    end
  }

  # create with open file
  let( :file_key ) { file_service.add_file('file1',nil,test_file1).tap do |key| created_files << key end }
  # create with file path
  let( :file_key2 ) { file_service.add_file(nil,nil,test_file2_path).tap do |key| created_files << key end }
  # create within dir
  let( :file_key3 ) { file_service.add_file(nil,dir_key,test_file1).tap do |key| created_files << key end }
  # create with block
  let( :file_key4 ) {
    file_service.add_file() do |file|
      IO.copy_stream(test_file2, file)
    end .tap do |key| created_files << key end
  }

  let( :dir_key ) { file_service.add_dir('dir1').tap do |key| created_files << key end }
  let( :dir_key2 ) { file_service.add_dir.tap do |key| created_files << key end }
  let( :dir_key3 ) { file_service.add_dir(nil,dir_key).tap do |key| created_files << key end }

  describe "#add_file" do
    it "in works using a specific path" do
      expect(file_service.file_exists?(file_key3)).to eql true
      test_file1.rewind
      expect(file_service.get_file(file_key3).read == test_file1.read).to eql true
    end

    it "works with a block" do
      expect(file_service.file_exists?(file_key4)).to eql true
      test_file2.rewind
      expect(file_service.get_file(file_key4).read == test_file2.read).to eql true
    end

    it "works with a file name" do
      expect(file_service.file_exists?(file_key2)).to eql true
      test_file2.rewind
      expect(file_service.get_file(file_key2).read == test_file2.read).to eql true
    end

    it "works with an open file" do
      expect(file_service.file_exists?(file_key)).to eql true
      test_file1.rewind
      expect(file_service.get_file(file_key).read == test_file1.read).to eql true
    end

    it "works with several files" do
      file_key; file_key2; file_key3; file_key4 # create some files with referencing
      test_file1.rewind
      test_file2.rewind
      expect(file_service.file_exists?(file_key)).to eql true
      expect(file_service.get_file(file_key).read == test_file1.read).to eql true
      expect(file_service.file_exists?(file_key4)).to eql true
      expect(file_service.get_file(file_key4).read == test_file2.read).to eql true
    end
  end

  describe "#add_dir" do
    context "in a specific path" do
      it "adds the directory" do
        expect(file_service.dir_exists?(dir_key3)).to eql true
      end

      it "raises an error if the path doesn't exist" do
        expect { file_service.add_dir('dir3','test') } .to raise_error(Hilda::Services::FileService::FileServiceError)
      end
    end

    it "adds the directory" do
      expect(file_service.dir_exists?(dir_key)).to eql true
      expect(file_service.dir_exists?(dir_key2)).to eql true
    end
  end

  describe "#file_exists?" do
    it "returns true when it does exist" do
      expect(file_service.file_exists?(file_key)).to eql true
      expect(file_service.file_exists?(file_key2)).to eql true
    end
    it "returns false when it doesn't exist" do
      file_service.remove_file(file_key)
      expect(file_service.file_exists?(file_key)).to eql false
    end
    it "returns false if not a file" do
      expect(file_service.file_exists?(dir_key)).to eql false
    end
  end

  describe "#dir_exists?" do
    it "returns true when it does exist" do
      expect(file_service.dir_exists?(dir_key)).to eql true
      expect(file_service.dir_exists?(dir_key2)).to eql true
    end
    it "returns false when it doesn't exist" do
      file_service.remove_file(dir_key)
      expect(file_service.dir_exists?(dir_key)).to eql false
    end
    it "returns false if not a dir" do
      expect(file_service.dir_exists?(file_key)).to eql false
    end
  end

  describe "#file_size" do
    it "raises an exception if file doesn't exist" do
      expect { file_service.file_size('/tmp/test') } .to raise_error(Hilda::Services::FileService::FileServiceError)
    end

    it "raises an exception if trying to get a directory" do
      expect { file_service.file_size(dir_key) } .to raise_error(Hilda::Services::FileService::FileServiceError)
    end

    it "returns the file size" do
      expect(file_service.file_size(file_key2)).to eql File.size(test_file2_path)
    end
  end

  describe "#get_file" do
    it "raises an exception if file doesn't exist" do
      expect { file_service.get_file('/tmp/test') } .to raise_error(Hilda::Services::FileService::FileServiceError)
    end

    it "raises an exception if trying to get a directory" do
      expect { file_service.get_file(dir_key) } .to raise_error(Hilda::Services::FileService::FileServiceError)
    end

    context "with a block" do
      it "returns the file" do
        file_key # add by referencing
        file_key2 # add by referencing
        file_read = false
        file_service.get_file(file_key) do |file|
          file_read = true
          test_file1.rewind
          expect(file.read == test_file1.read).to eql true
        end
        expect(file_read).to eql true
        file_read = false
        ret = file_service.get_file(file_key2) do |file|
          file_read = true
          test_file2.rewind
          expect(file.read == test_file2.read).to eql true
          'return value'
        end
        expect(ret).to eql 'return value'
        expect(file_read).to eql true
      end
    end
    context "without a block" do
      it "returns the file" do
        file_key # add by referencing
        file_key2 # add by referencing
        open_file = file_service.get_file(file_key)
        test_file1.rewind
        expect(open_file.read == test_file1.read).to eql true
        open_file.close
        open_file = file_service.get_file(file_key2)
        test_file2.rewind
        expect(open_file.read == test_file2.read).to eql true
        open_file.close
      end
    end
  end

  describe "#remove_file" do
    it "removes the file or directory" do
      expect(file_service.file_exists?(file_key)).to eql true
      expect(file_service.file_exists?(file_key2)).to eql true
      expect(file_service.dir_exists?(dir_key)).to eql true
      file_service.remove_file(file_key)
      expect(file_service.file_exists?(file_key)).to eql false
      expect(file_service.file_exists?(file_key2)).to eql true
      expect(file_service.dir_exists?(dir_key)).to eql true
      file_service.remove_file(file_key2)
      expect(file_service.file_exists?(file_key2)).to eql false
      expect(file_service.dir_exists?(dir_key)).to eql true
      file_service.remove_file(dir_key)
      expect(file_service.dir_exists?(dir_key)).to eql false
    end
  end

end
