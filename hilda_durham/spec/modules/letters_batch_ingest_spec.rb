require 'rails_helper'

RSpec.describe HildaDurham::Modules::LettersBatchIngest do

  let( :graph ) { 
    Hilda::ModuleGraph.new.tap do |graph|
      allow(graph).to receive(:file_service).and_return(file_service)
    end
  }
  let( :file_service ) {
    double('file_service').tap do |fs|
      allow(fs).to receive(:get_file) do |path,&block|
        raise "invalid path #{path}" unless path == 'batch_metadata.csv'
        block.call(batch_metadata)
      end
    end
  }
  let( :batch_metadata ) { fixture('letters_batch.csv') }
  let( :mod_params ) { {
      ingest_root: '/tmp/ingest_test',
      title_base: 'Test Letters ',
      licence: 'Test licence',
      attribution: 'Test attribution'
    } }
  let( :mod_input ) { {
    source_files: { 'batch_metadata.csv' => {
      path: 'batch_metadata.csv'
    } },
    trifle_collection: 'trifle_test_collection'
  } }
  let( :mod ) { 
    graph.add_start_module(HildaDurham::Modules::LettersBatchIngest, mod_params).tap do |mod|
      allow(mod).to receive(:module_input).and_return(mod_input)
      mod.assign_job_tag
      mod.module_output = {}
    end
  }
  
  describe "#oubliette_module" do
    it "returns OublietteIngest module" do
      expect(mod.oubliette_module).to be_a(HildaDurham::Modules::OublietteIngest)
    end
    it "allows module_input to be called" do
      expect(mod.oubliette_module.module_input).to eql({})
    end
  end
  
  describe "#trifle_module" do
    it "returns TrifleIngest module" do
      expect(mod.trifle_module).to be_a(HildaDurham::Modules::TrifleIngest)
    end
    it "allows module_input to be called" do
      expect(mod.trifle_module.module_input).to eql({})
    end
  end
  
  describe "#set_sub_module_input" do
    let(:letter_data){
      {
        source_files: {
          'file1.tiff' => { path: 'file1.tiff', original_filename: 'file1.tiff', content_type: 'image/tiff', md5: 'abcd'},
          'file2.tiff' => { path: 'file2.tiff', original_filename: 'file2.tiff', content_type: 'image/tiff', md5: 'abcd'}
        },
        oubliette_files: ['file1', 'file2'], # really an array of hashes
        title: 'Test title',
        date: '1987',
        author: 'Test author',
        description: 'Test description',
        source_record: 'ark:/12345/abcdefgh',
        source_fragment: 'ABC-1'
      }
    }
    let(:module_input) { {} }
    before {
      mod.set_sub_module_input(module_input, letter_data)
    }
    it "sets module_input data" do
      expect(module_input[:process_metadata][:title]).to eql('Test title')
      expect(module_input[:process_metadata][:date]).to eql('1987')
      expect(module_input[:process_metadata][:author]).to eql('Test author')
      expect(module_input[:process_metadata][:description]).to eql('Test description')
      expect(module_input[:process_metadata][:licence]).to eql('Test licence')
      expect(module_input[:process_metadata][:attribution]).to eql('Test attribution')
      expect(module_input[:process_metadata][:source_record]).to eql('schmit:ark:/12345/abcdefgh#ABC-1')
      expect(module_input[:source_files]).to eql(letter_data[:source_files])
      expect(module_input[:stored_files]).to eql(letter_data[:oubliette_files])
      expect(module_input[:file_metadata][:"file1.tiff__title"]).to eql('1')
      expect(module_input[:file_metadata][:"file2.tiff__title"]).to eql('2')
      expect(module_input[:trifle_collection]).to eql('trifle_test_collection')
    end
    context "with process_metadata set" do
      let( :mod_input ) { {
        source_files: { 'batch_metadata.csv' => {
          path: 'batch_metadata.csv'
        } },
        trifle_collection: 'trifle_test_collection',
        process_metadata: {licence: 'Process licence', attribution: 'Process attribution'}
      } }      
      it "uses process_metadata licence and attribution" do
        expect(module_input[:process_metadata][:licence]).to eql('Process licence')
        expect(module_input[:process_metadata][:attribution]).to eql('Process attribution')
      end
    end
  end
  
  describe "#fetch_linked_metadata" do
    let(:schmit_record) { double('schmit_record', xml_record: ead_record) }
    let(:ead_record) { 
      double('ead_record').tap do |r|
        allow(r).to receive(:sub_item).with(record_fragment).and_return(sub_record)
      end
    }
    let(:sub_record) { double('sub_record') }
    let(:source_id) { 'ark:/12345/abcdefgh' }
    let(:record_fragment) { 'ABC-1' }
    before {
      allow(Schmit::API::Catalogue).to receive(:find).with(source_id).and_return(schmit_record)
    }
    it "returns fetched record" do
      expect(mod.fetch_linked_metadata(source_id,nil)).to eql(ead_record)
      expect(mod.fetch_linked_metadata(source_id,record_fragment)).to eql(sub_record)
    end
    it "cachecs records" do
      expect(mod.fetch_linked_metadata(source_id,record_fragment)).to eql(sub_record)
      expect(Schmit::API::Catalogue).not_to receive(:find)
      expect(mod.fetch_linked_metadata(source_id,record_fragment)).to eql(sub_record)
    end
  end
  
  describe "#populate_source_metadata" do
    let(:source_id) { 'ark:/12345/abcdefgh' }
    let(:record_fragment) { 'ABC-1' }
    let(:ead_record) { 
      double('ead_record', title: 'Record title', id: 'record_id', date: 'Record date', scopecontent: 'Record description', author: 'Record author')
    }
    before {
      allow(mod).to receive(:fetch_linked_metadata).with(source_id,record_fragment).and_return(ead_record)
    }
    it "doesn't do anything if no source_record" do
      expect(mod).not_to receive(:fetch_linked_metadata)
      input = {}
      expect(mod.populate_source_metadata(input)).to eql(true)
      expect(input).to eql({})
    end
    it "doesn't overwrite metadata" do
      input = {source_record: source_id, source_fragment: record_fragment, title: 'Test title', date: 'Test date', description: 'Test description', author: 'Test author'}
      expect(mod.populate_source_metadata(input)).to eql(true)
      expect(input[:title]).to eql('Test title')
      expect(input[:date]).to eql('Test date')
      expect(input[:description]).to eql('Test description')
      expect(input[:author]).to eql('Test author')
    end
    it "fills in metadata" do
      input = {source_record: source_id, source_fragment: record_fragment}
      expect(mod.populate_source_metadata(input)).to eql(true)
      expect(input[:title]).to eql('Test Letters Record title') # concatenated with title base in options
      expect(input[:date]).to eql('Record date')
      expect(input[:description]).to eql('Record description')
      expect(input[:author]).to eql('Record author')
    end
  end
  
  describe "#ingest_oubliette" do
    let(:letter_data) { 
      double('letter').tap do |letter| 
        allow(letter).to receive(:[]).with(:title).and_return("Test title")
        allow(letter).to receive(:[]).with(:folder).and_return("test/folder")
      end
    }
    let(:stored_files) { double('stored_files') }
    
    it "calls methods" do
      expect(mod).to receive(:set_sub_module_input).with(mod.oubliette_module.module_input, letter_data)
      expect(mod.oubliette_module).to receive(:run_module) do
        mod.oubliette_module.module_output[:stored_files] = stored_files
      end
      expect(letter_data).to receive(:[]=).with(:oubliette_files, stored_files)
      expect(mod.ingest_oubliette(letter_data)).to eql(true)
      expect(mod.oubliette_module.job_tag).to eql(mod.job_tag+'/test/folder')
    end
  end
  
  describe "#ingest_trifle" do
    let(:letter_data) { 
      double('letter').tap do |letter| 
        allow(letter).to receive(:[]).with(:title).and_return("Test title")
        allow(letter).to receive(:[]).with(:folder).and_return("test/folder")
      end
    }
    
    it "calls methods" do
      expect(mod).to receive(:set_sub_module_input).with(mod.trifle_module.module_input, letter_data)
      expect(mod.trifle_module).to receive(:run_module) do 
        mod.trifle_module.module_output[:trifle_manifest] = {'id' => 't0test'}
      end
      expect(mod.ingest_trifle(letter_data)).to eql(true)
      expect(mod.module_output[:trifle_manifests]).to eql(['t0test'])
      expect(mod.trifle_module.job_tag).to eql(mod.job_tag+'/test/folder')
    end
  end
  
  describe "#resolve_path" do
    it "concatenates paths" do
      expect(mod.resolve_path('moo/baa.tiff')).to eql('/tmp/ingest_test/moo/baa.tiff')
    end
    it "sanity checks" do
      expect(mod.resolve_path('../moo.tiff')).to be(nil)
    end
  end
  
  describe "#list_files" do
  end
  
  describe "#calculate_md5" do
    let!(:temp_file){
      Tempfile.new('md5_test_temp').tap do |file|
        file.write('abcd')
        file.close
      end
    }
    after {
      temp_file.unlink 
    }
    it "returns md5" do
      expect(mod.calculate_md5(temp_file.path)).to eql('e2fc714c4727ee9395f324cd2e7f331f')
    end
  end
  
  describe "#read_letters_data" do
    let!(:temp_dir) { 
      Dir.mktmpdir.tap do |temp_dir|
        mod_params[:ingest_root] = temp_dir
      end
    }
    let!(:letters1_dir) { File.join(temp_dir,"Letters_1").tap do |dir| Dir.mkdir(dir) end }
    let!(:letters2_dir) { File.join(temp_dir,"Letters_2").tap do |dir| Dir.mkdir(dir) end }
    let!(:temp_file1) { 
      File.open(File.join(letters1_dir,'test1.tiff'),'wb') do |file| 
        file.write('1234')
        file.path
      end 
    }
    let!(:temp_file2) { 
      File.open(File.join(letters1_dir,'test2.tiff'),'wb') do |file| 
        file.write('5678')
        file.path
      end 
    }
    let!(:temp_file3) { 
      File.open(File.join(letters2_dir,'test1.tiff'),'wb') do |file| 
        file.write('9012')
        file.path
      end 
    }
    after {
      File.unlink(temp_file1)
      File.unlink(temp_file2)
      File.unlink(temp_file3)
      Dir.rmdir(letters1_dir)
      Dir.rmdir(letters2_dir)
      Dir.rmdir(temp_dir)
    }
    it "reads letters data" do
      expect(mod).to receive(:populate_source_metadata).exactly(2).times
      mod.read_letters_data
      expect(mod.letters).to eql(
      [
        {
          folder: "Letters_1/",
          title: "Test Letters L1",
          date: "1892",
          author: "Test Author",
          description: "Letters from foo to bar relating to moo",
          source_record: "ark:/12345/abcdegh",
          source_fragment: "ABC-1",
          source_files: {
            "test1.tiff" => {
              path: "#{letters1_dir}/test1.tiff",
              original_filename: "test1.tiff",
              content_type: "image/tiff",
              md5: "81dc9bdb52d04dc20036dbd8313ed055"
            },
            "test2.tiff" => {
              path: "#{letters1_dir}/test2.tiff",
              original_filename: "test2.tiff",
              content_type: "image/tiff",
              md5: "674f3c2c1a8a6f90461e8a66fb5550ba"
            }
          }
        },
        {
          folder: "Letters_2/",
          title: "Test Letters L2 – test",
          date: "1895",
          author: "Test Author",
          description: "Letters from bar to foo relating to baa",
          source_record: "ark:/12345/ijklmno",
          source_fragment: "ABC-2",
          source_files: {
            "test1.tiff"=> {
              path: "#{letters2_dir}/test1.tiff",
              original_filename: "test1.tiff",
              content_type: "image/tiff",
              md5: "c5c53759e4dd1bfe8b3dcfec37d0ea72"
            }
          }
        }
      ])
      expect(mod.letters[1][:title].encoding.to_s).to eql('UTF-8')
    end
  end
  
  describe "#ingest_letter" do
    let(:letter) { double('letter') }
    it "calls functions" do
      expect(mod).to receive(:ingest_oubliette).with(letter).and_return(true)
      expect(mod).to receive(:ingest_trifle).with(letter).and_return(true)
      expect(mod.ingest_letter(letter)).to eql(true)
    end
    it "hats if anything fails" do
      expect(mod).to receive(:ingest_oubliette).with(letter).and_return(false)
      expect(mod).not_to receive(:ingest_trifle)
      expect(mod.ingest_letter(letter)).to eql(false)
    end
  end
  
  describe "#run_module" do
    it "halts if read_letters_data fails" do
      expect(mod).to receive(:read_letters_data).and_return(false)
      expect(mod).not_to receive(:ingest_letter)
      mod.run_module
      expect(mod.run_status).to eql(:error)
    end
    it "calls all the methods" do
      mod.instance_variable_set(:@letters,[double('letter1'),double('letter2')])
      expect(mod).to receive(:read_letters_data).and_return(true)
      expect(mod).to receive(:ingest_letter).exactly(:twice).and_return(true)
      mod.run_module
      expect(mod.run_status).not_to eql(:error)
    end
  end  

end