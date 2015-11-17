require 'rails_helper'

RSpec.describe Hilda::FileServiceFile do
  let( :file1 ) { Hilda::FileServiceFile.new(file_type: Hilda::FileServiceFile::TYPE_FILE) }
  let( :file2 ) {
    Hilda::FileServiceFile.new(file_type: Hilda::FileServiceFile::TYPE_FILE).tap do |file2|
      file2.file_contents.content = 'abc'
    end
  }
  let( :dir1 ) { Hilda::FileServiceFile.new(file_type: Hilda::FileServiceFile::TYPE_DIRECTORY) }

  describe "validation" do
    it "returns true when valid" do
      expect(file1).to be_valid
      expect(file2).to be_valid
      expect(dir1).to be_valid
    end

    it "file cannot be in another file" do
      file1.directory = file2
      expect(file1).not_to be_valid
    end

    it "directory cannot have contents" do
      dir1.file_contents.content = 'abc'
      expect(dir1).not_to be_valid
    end
  end

end
