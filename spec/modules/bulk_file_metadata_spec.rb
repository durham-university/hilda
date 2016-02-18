require 'rails_helper'

RSpec.describe Hilda::Modules::BulkFileMetadata do
  let( :simple_metadata_fields) { { title: {label: 'title', type: :string } } }
  let( :complex_metadata_fields) { { title: {label: 'title', type: :string }, tag: {label: 'tag', type: :string, default: 'moo'} } }
  let( :metadata_fields ) { simple_metadata_fields }
  
  let( :file_names ) { ['f1','f2','f3'] }
  let( :graph ) { 
    Hilda::ModuleGraph.new.tap do |graph| 
      graph[:source_file_names] = file_names
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
      expect(mod).to receive(:parse_bulk_params).with({'bulk_data' => 'moo'}).and_return({'moo' => 'baa'})
      mod.receive_params({'bulk_data' => 'moo'})
      expect(mod.param_values[:bulk_data]).to eql('moo')
    end
    
  end
  
  describe "#parse_bulk_params" do
    let(:parsed) { mod.parse_bulk_params({'bulk_data' => input}) }
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
      let(:input) { "test1;foo1\ntest2;foo2\ntest3" }
      it "parses" do
        expect(parsed).to eql({ 
          'f1__title' => 'test1',
          'f1__tag' => 'foo1',
          'f2__title' => 'test2',
          'f2__tag' => 'foo2',
          'f3__title' => 'test3'
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