require 'rails_helper'

RSpec.describe Hilda::Modules::DebugModule do
  let( :graph ) { Hilda::ModuleGraph.new }
  let( :mod ) { graph.add_start_module(Hilda::Modules::DebugModule, module_params) }
  let( :module_params ) { {} }

  describe "#initialize" do
    it "works on its own" do
      expect(mod).to be_a Hilda::Modules::DebugModule
    end

    describe "with param defs" do
      let( :module_params ) { {param_defs: { test: {label: 'test', type: :string} }} }
      it "sets param_defs" do
        expect(mod.param_defs).to eql({ test: {label: 'test', type: :string, default: nil, group: nil, collection: nil, optional: false, note: nil} })
      end
    end
  end

  describe "#autorun?" do
    let( :module_params ) { {autorun: 'moo'} }
    it "sets param_defs" do
      expect(mod.autorun?).to eql 'moo'
    end
  end

  describe "#run_module" do
    before {
      allow(mod).to receive(:module_input).and_return( {moo: 'oink'} )
    }
    it "outputs input verbatim by default" do
      mod.run_module
      expect(mod.module_output).to eql({moo: 'oink'})
    end
    describe "with output defined" do
      let( :module_params ) { {module_output: {baa: 'moo'}} }
      it "outputs what's given" do
        mod.run_module
        expect(mod.module_output).to eql({baa: 'moo'})
      end
    end
  end
end
