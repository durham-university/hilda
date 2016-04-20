require 'rails_helper'

RSpec.describe HildaDurham::Modules::LibraryLinker do

  let( :graph ) { Hilda::ModuleGraph.new }
  let( :mod_params ) { {} }
  let( :mod ) { graph.add_start_module(HildaDurham::Modules::LibraryLinker, mod_params) }
  
  describe "#validate_reference" do
    let(:record) { double('record') }
    it "returns true when record exists" do
      expect(mod).to receive(:selected_record).and_return(record)
      expect(mod.validate_reference).to eql(true)
    end
    it "returns false when record doesn't exist" do
      expect(mod).to receive(:selected_record).and_return(nil)
      expect(mod.validate_reference).to eql(false)
    end
  end
  
  describe "#selected_record" do
    let(:exists) { true }
    let(:adlib_record) { double('adlib record', exists?: exists) }
    let(:millenium_record) { double('millenium record', exists?: exists) }
    let(:schmit_record) { double('schmit record', xml_record: schmit_xml_record) }
    let(:schmit_xml_record) { double('schmit xml record', root_item: schmit_root_record) }
    let(:schmit_root_record) { double('schmit root record', exists?: exists) }
    let(:schmit_sub_record) { double('schmit sub record', exists?: exists) }
    let(:adlib_connection) { double('adlib connection') }
    let(:millenium_connection) { double('adlib connection') }
    before {
      allow(DurhamRails::LibrarySystems::Adlib).to receive(:connection).and_return(adlib_connection)
      allow(DurhamRails::LibrarySystems::Millenium).to receive(:connection).and_return(millenium_connection)
      allow(adlib_connection).to receive(:record).with('adlibid').and_return(adlib_record)
      allow(millenium_connection).to receive(:record).with('milleniumid').and_return(millenium_record)
      allow(Schmit::API::Catalogue).to receive(:find).with('schmitid').and_return(schmit_record)
    }
    it "returns adlib record when type is adlib" do
      mod.param_values[:library_record_id] = 'adlibid'
      mod.param_values[:library_record_type] = 'Adlib'
      expect(mod.selected_record).to eql(adlib_record)
    end
    
    it "returns millenium record when type is millenium" do
      mod.param_values[:library_record_id] = 'milleniumid'
      mod.param_values[:library_record_type] = 'Millenium'
      expect(mod.selected_record).to eql(millenium_record)
    end
    
    it "returns schmit record when type is schmit" do
      mod.param_values[:library_record_id] = 'schmitid'
      mod.param_values[:library_record_type] = 'Schmit'
      expect(mod.selected_record).to eql(schmit_root_record)
      
      mod.param_values[:library_record_fragment] = 'fragment'
      expect(schmit_xml_record).to receive(:sub_item).with('fragment').and_return(schmit_sub_record)
      expect(mod.selected_record).to eql(schmit_sub_record)      
    end
    
    it "returns nil if type not set" do
      mod.param_values[:library_record_id] = 'adlibid'
      expect(mod.selected_record).to eql(nil)
    end
    
    context "when record doesn't exist" do
      let(:exists) { false }
      it "returns nil" do
        mod.param_values[:library_record_id] = 'adlibid'
        mod.param_values[:library_record_type] = 'adlib'
        expect(mod.selected_record).to eql(nil)
      end
    end
  end
  
  describe "#receive_params" do
    it "caches record label" do
      expect(mod).to receive(:fetch_selected_record_label)
      mod.receive_params({})
    end
  end
  
  describe "#fetch_selected_record_label" do
    let(:record) { 
      # fetch_selected_record_label checks object type so create the mock this way
      Object.new.tap do |obj|
        class << obj
          include DurhamRails::RecordFormats::AdlibRecord
        end
        allow(obj).to receive(:title).and_return('record name')
      end
    }
    it "sets record name" do
      expect(mod).to receive(:selected_record).and_return(record)
      mod.fetch_selected_record_label
      expect(mod.param_values[:selected_library_record_label]).to eql('record name')
    end
  end
  
  describe "#selected_record_label" do
    it "uses cached label" do
      mod.param_values[:selected_library_record_label] = 'record name'
      expect(mod.selected_record_label).to eql('record name')
    end
  end
  
  describe "#adapt_record_to_params" do
  end

  describe "#run_module" do
    before {
      mod_params.merge!({
          library_record_type: 'adlib',
          library_record_id: '12345'
        })
      mod.module_output={}
      mod.run_status = :running
    }

    it "sets selected record and type" do
      expect(mod).to receive(:validate_reference).and_return(true)
      expect(mod).to receive(:adapt_record_to_params).and_return({moo: 'moo'})
      mod.run_module
      expect(mod.run_status).to eql :running # graph sets it to finished
      expect(mod.module_output).to eql({ library_link: { type: 'adlib', record_id: '12345', fragment_id: nil}, process_metadata: {moo: 'moo'} })
    end
    
    it "validates reference and sets error if invalid" do
      expect(mod).to receive(:validate_reference).and_return(false)
      mod.run_module
      expect(mod.run_status).to eql :error
      expect(mod.module_output).to eql({})
    end
  end

end