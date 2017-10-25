require 'rails_helper'

RSpec.describe Hilda::Modules::BulkFileMetadata do
  let( :simple_metadata_fields) { { title: {label: 'title', type: :string } } }
  let( :complex_metadata_fields) { { title: {label: 'title', type: :string }, tag: {label: 'tag', type: :string, default: 'moo'}, description: {label: 'description', type: :string, optional: true} } }
  let( :metadata_fields ) { simple_metadata_fields }
  
  let( :file_names ) { ['f1','f2','f3'] }
  let( :graph ) { 
    Hilda::ModuleGraph.new.tap do |graph| 
      graph.graph_params[:source_file_names] = file_names
    end 
  }
  let( :mod ) {
    graph.add_start_module(Hilda::Modules::BulkFileMetadata, metadata_fields: metadata_fields).tap do |mod|
      mod.build_param_defs
    end
  }
  
  describe "#groups" do
    let( :metadata_fields ) { complex_metadata_fields }
    it "gives correct groups" do
      expect(mod.groups).to eql(['f1','f2','f3'])
    end
  end
  
  describe "#receive_params" do
    it "calls #parse_bulk_params and sets bulk_data param" do
      expect(mod).to receive(:parse_bulk_params) do 
        expect(mod.param_values[:bulk_data]).to eql('moo')
      end .and_return({'moo' => 'baa'})
      mod.receive_params({'bulk_data' => 'moo'})
    end
  end
  
  describe "#set_default_values" do
    before {
      class TestSetter
        def self.default_file_labels(files)
        end
      end
    }
    after {
      Object.send(:remove_const,:TestSetter)
    }
    let(:file_list) { ['testfile.tiff','testfile2.tiff'] }
    let(:file_labels) { ['test1','test2'] }
    let(:defaults_mock) { double('defaults') }
    it "calls setter if specified in options" do
      mod.param_values[:defaults_setter]='TestSetter'
      expect(mod).to receive(:groups).and_return(file_list)
      expect(TestSetter).to receive(:default_file_labels).with(file_list).and_return(file_labels)
      expect(mod).to receive(:receive_params).with(hash_including(mod.data_key => file_labels.join("\n")))
      mod.set_default_values
    end
    it "does nothing if not specified in options" do
      expect(mod).not_to receive(:receive_params)
      expect(TestSetter).not_to receive(:default_file_labels)
      expect {
        mod.set_default_values
      } .not_to raise_error
    end
  end
  
  describe "#all_params_valid?" do
    it "returns true when bulk line count matches group count" do
      mod.receive_params({'bulk_data' => "aa\nbb\ncc"})
      expect(mod.all_params_valid?).to eql(true)
    end
    it "returns false when bulk data has too many lines" do
      mod.receive_params({'bulk_data' => "aa\nbb\ncc\ndd"})
      expect(mod.all_params_valid?).to eql(false)
    end
    it "returns false when bulk data has too few lines" do
      mod.receive_params({'bulk_data' => "aa\nbb"})
      expect(mod.all_params_valid?).to eql(false)
    end
    context "with complex defs" do
      let( :metadata_fields ) { complex_metadata_fields }
      before {  mod.param_values[:data_delimiter] = ',' }
      it "handles default values" do
        mod.receive_params({'bulk_data' => "aa\nbb,cc\ndd,ee,ff"})
        expect(mod.all_params_valid?).to eql(true)
      end
    end
  end
  
  describe "#parse_bulk_params" do
    before { mod.param_values[:bulk_data] = input }
    let(:parsed) { mod.parse_bulk_params }
    context "without splitting lines" do
      before { expect(mod.data_delimiter).to eql(nil) }
      # Note windows line breaks in input
      let(:input) { "test1\r\ntest2\r\ntest3" }
      it "parses" do
        expect(parsed).to eql({ 'f1__title' => 'test1', 'f2__title' => 'test2', 'f3__title' => 'test3'})
      end
    end
    context "with splitting lines" do
      let( :metadata_fields ) { complex_metadata_fields }
      before { 
        mod.param_values[:data_delimiter] = ';'
        expect(mod.data_delimiter).to eql(';')
      }
      let(:input) { "test1;foo1\ntest2;foo2;bar2\ntest3;;bar3" }
      it "parses" do
        expect(parsed).to eql({ 
          'f1__title' => 'test1',
          'f1__tag' => 'foo1',
          'f2__title' => 'test2',
          'f2__tag' => 'foo2',
          'f2__description' => 'bar2',
          'f3__title' => 'test3',
          'f3__description' => 'bar3'
        })
      end
    end
  end
  
  describe "#receive_params" do
    it "sets param_values" do
      mod.receive_params({'bulk_data' => "test1\ntest2\ntest3"})
      expect(mod.param_values[:f1__title]).to eql 'test1'
      expect(mod.param_values[:f2__title]).to eql 'test2'
      expect(mod.param_values[:f3__title]).to eql 'test3'
    end
  end

end