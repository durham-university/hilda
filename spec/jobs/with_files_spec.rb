require 'rails_helper'

RSpec.describe 'WithFiles' do
  before {
    class FooJob
      include Hilda::Jobs::JobBase
      include Hilda::Jobs::WithFiles
    end
  }
  after {
    Object.send(:remove_const,:FooJob)
  }
  let( :job ) { FooJob.new() }
  let( :file ) { StringIO.new('moomoo') }
  let( :file_table ) { job.instance_variable_get(:@file_table) }

  describe 'temp dir' do
    before { @tmp_dir_was = Hilda.config['job_temp_dir'] }
    after { Hilda.config['job_temp_dir'] = @tmp_dir_was }
    it "uses system temp directory by default" do
      Hilda.config['job_temp_dir'] = nil
      expect(job.temp_dir).to eql(Dir.tmpdir)
    end

    it "uses given temp directory" do
      Hilda.config['job_temp_dir'] = '/footmp'
      expect(job.temp_dir).to eql('/footmp')
    end

    it "generates temp file paths under the temp dir" do
      Hilda.config['job_temp_dir'] = "#{File::SEPARATOR}tmp"
      path = job.send(:make_temp_file_path)
      expect( path ).to start_with( "#{File::SEPARATOR}tmp#{File::SEPARATOR}")
      expect( path.length ).to be > '/tmp/'.length
    end
  end

  describe 'files' do
    describe 'setting files' do
      describe '#set_file' do
        it "sets the default file" do
          job.set_file(file)
          expect( file_table[:default] ).to eql(file)
        end
      end

      describe '#add_file' do
        it "sets the specified file" do
          job.add_file(:baa,file)
          expect( file_table[:baa] ).to eql(file)
        end
      end
    end

    describe 'getting files' do
      describe '#get_file default' do
        it "sets the default file" do
          job.set_file(file)
          expect( job.get_file ).to eql(file)
        end
      end
      describe '#get_file' do
        it "sets the specified file" do
          job.add_file(:moo,file)
          expect( job.get_file(:moo) ).to eql(file)
        end
      end
    end
  end

  describe "validation" do
    it "is valid with proper files" do
      expect { job.validate_job! }.not_to raise_error
    end

    it "it raises an error with invalid files" do
      job.add_file(:invalid,"doesn't respond to read")
      expect { job.validate_job! }.to raise_error('Invalid file')
    end
  end

  describe "marshalling" do
    before { job.add_file(:moo,file) }
    describe "dumping" do
      let( :dump ) {
        allow(job).to receive(:store_files).and_return(nil)
        job.file_paths[:moo] = job.send(:make_temp_file_path)
        Marshal.dump(job)
      }
      it "shouldn't contain file data" do
        expect(dump).not_to include 'moomoo'
      end
      it "should have the file path" do
        expect(dump).to include job.file_paths[:moo]
      end
    end

    describe "storing files" do
      it "calls store_files" do
        expect(job).to receive(:store_files).and_return(nil)
        Marshal.dump(job)
      end

      it "stores file contents and sets file paths" do
        Marshal.dump(job)
        expect( job.file_paths[:moo] ).to be_present
        expect( job.file_paths[:moo] ).to start_with job.temp_dir
        expect( File.exists?(job.file_paths[:moo]) ).to be_truthy
        file = File.new(job.file_paths[:moo])
        begin
          contents = file.read
          expect( contents ).to eql "moomoo"
        ensure
          File.unlink(file)
        end
      end
    end

    describe "loading files" do
      it "loads files when deserialising" do
        dumped = Marshal.dump(job)
        begin
          job_new = Marshal.load( dumped )
          file = job_new.get_file(:moo)
          expect( file ).to be_present
          expect( file.read ).to eql 'moomoo'
        ensure
          File.unlink(job.file_paths[:moo]) if job.file_paths[:moo].start_with? job.temp_dir
        end
      end
    end
  end

  describe "removing files" do
    it "calls remove_files when job finishes" do
      resource_double = double()
      allow(resource_double).to receive(:background_job_finished)
      job.instance_variable_set(:@resource,resource_double)

      expect(job).to receive(:remove_files).and_return(nil)
      job.job_finished
    end

    it "unlinks files" do
      file_double1 = double('1')
      allow(file_double1).to receive(:path).and_return(File.join(job.temp_dir,'test1'))
      expect(File).to receive(:unlink).with(file_double1)
      file_double2 = double('2')
      allow(file_double2).to receive(:path).and_return(File.join(job.temp_dir,'test2'))
      expect(File).to receive(:unlink).with(file_double2)

      job.instance_variable_set(:@file_table,{})
      job.add_file(:moo,file_double1)
      job.add_file(:baa,file_double2)

      job.send(:remove_files)
    end
  end

end
