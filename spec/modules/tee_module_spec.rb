require 'rails_helper'

RSpec.describe Hilda::Modules::TeeModule do
  before {
    class ModClass
      include Hilda::ModuleBase
      include Hilda::Modules::TeeModule
    end
  }
  after { Object.send(:remove_const,:ModClass) }
  let( :source1_params ) { { module_name: 'source1', module_output: {moo: 'moo'} } }
  let( :source2_params ) { { module_name: 'source2', module_output: {baa: 'baa'} } }
  let( :source3_params ) { { module_name: 'source3',module_output: {oink: 'oink'} } }
  let( :source1 ) { graph.add_start_module(Hilda::Modules::DebugModule, source1_params) }
  let( :source2 ) { graph.add_start_module(Hilda::Modules::DebugModule, source2_params) }
  let( :source3 ) { graph.add_start_module(Hilda::Modules::DebugModule, source3_params) }
  let( :mod ) {
    ModClass.new(graph).tap do |mod|
      graph.add_module(mod, source1)
      graph.add_module(mod, source2)
      graph.add_module(mod, source3)
    end
  }
  let( :graph ) { Hilda::ModuleGraph.new }

  describe "#ready_to_run?" do
    it "returns true if have all inputs" do
      source1.run_status=:finished # super returns false otherwise
      expect(mod).to receive(:have_all_inputs?).and_return(true)
      expect(mod.ready_to_run?).to eql(true)
    end
    it "returns false if it doesn't have all inputs" do
      allow(mod).to receive(:have_all_inputs?).and_return(false)
      expect(mod.ready_to_run?).to eql(false)
    end
    it "calls super" do
      allow(mod).to receive(:have_all_inputs?).and_return(true)
      mod.run_status=:finished
      expect(mod.ready_to_run?).to eql(false)
    end
  end
  
  describe "#have_all_inputs?" do
    it "checks all inputs" do
      expect(mod.have_all_inputs?).to eql(false)
      source1.run_status=:finished
      source2.run_status=:finished
      expect(mod.have_all_inputs?).to eql(false)
      source3.run_status=:finished
      expect(mod.have_all_inputs?).to eql(true)      
    end
  end
  
  describe "#module_sources" do
    it "returns all source modules" do
      expect(mod.module_sources).to eql({0 => source1, 1 => source2, 2 => source3})
    end
    it "uses set connector names" do
      mod.set_connector_name(source1, :a)
      mod.set_connector_name(source3, :c)
      expect(mod.module_sources).to eql({'a' => source1, 1 => source2, 'c' => source3})      
    end
  end
  
  describe "#set_connector_name and #connector_name" do
    it "converts name to string and stores it" do
      mod.set_connector_name(source1, :a)
      expect(mod.connector_name(source1)).to eql('a')
      expect(mod.connector_name(source1.module_name)).to eql('a')
    end
  end
  
  describe "#module_input" do
    before {
      [source1, source2, source3].each do |source_mod|
        source_mod.run_status = :finished
        source_mod.module_output = source_mod.param_values[:module_output]
      end
    }
    it "returns output of sources" do
      expect(mod).to receive(:module_sources).and_call_original
      expect(mod.module_input).to eql({0 => {moo:'moo'}, 1 => {baa:'baa'}, 2 => {oink:'oink'}})
    end
    it "works with set connector names" do
      mod.set_connector_name(source1, :a)
      mod.set_connector_name(source3, :c)
      expect(mod.module_input).to eql({'a' => {moo:'moo'}, 1 => {baa:'baa'}, 'c' => {oink:'oink'}})
    end
    it "returns nil if a module hasn't finished" do
      source1.run_status = :initialized
      expect(mod.module_input).to be_nil
    end
  end
  
  describe "#as_json" do
    before {
      mod.set_connector_name(source1, :a)
      mod.set_connector_name(source3, :c)      
    }
    let(:json) { mod.as_json }
    it "stores connector names in json" do
      expect(json[:connectors]).to eql({'source1' => 'a', 'source3' => 'c'})
    end
    it "calls super" do
      expect(json[:run_status]).to eql(:initialized)
    end
  end
  
  describe "running graph with tee modules" do
    let!(:dest) { graph.add_module(Hilda::Modules::DebugModule, mod) }
    it "graph runs and tee waits for all inputs" do
      mod.set_connector_name(source1, :a)
      mod.set_connector_name(source3, :c)
      allow(mod).to receive(:autorun?).and_return(true)
      expect(mod).to receive(:run_module).once {
        expect(mod.module_input).to eql({'a' => {moo:'moo'}, 1 => {baa:'baa'}, 'c' => {oink:'oink'}})
        mod.module_output = { foo: 'bar' }
      }
      graph.start_graph
      expect(mod.module_output).to eql({foo:'bar'})
      expect(mod.run_status).to eql(:finished)
      expect(dest.module_output).to eql({foo:'bar'})
      expect(dest.run_status).to eql(:finished)
    end
  end

end