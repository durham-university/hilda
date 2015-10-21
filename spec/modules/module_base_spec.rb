require 'rails_helper'

RSpec.describe Hilda::ModuleGraph do
  before {
    class TestModule
      include Hilda::ModuleBase
    end
  }
  let!( :mod ) { graph.add_start_module(TestModule, module_name: 'module name', autorun: false, test_out: 'test' ) }

  let!( :graph ) { Hilda::ModuleGraph.new }

  after{ Object.send(:remove_const, :TestModule) }

  describe "#initialize" do
    it "sets initial values" do
      expect(mod.module_name).to eql 'module name'
      expect(mod.run_status).to eql :initialized
      expect(mod.log).not_to be_nil
      expect(mod.module_graph).to be_a Hilda::ModuleGraph
      expect(mod.param_values[:test_out]).to eql 'test'
    end
  end

  describe "#default_module_name" do
    it "returns something" do
      expect(mod.default_module_name).to be_a String
      expect(mod.default_module_name).to be_present
    end
    it "copes with duplicate module classes" do
      mod2 = graph.add_start_module(TestModule)
      mod3 = graph.add_start_module(TestModule)
      expect(mod2.module_name).to be_present
      expect(mod3.module_name).to be_present
      expect(mod2.module_name).not_to eql mod3.module_name
    end
  end

  describe "#add_module" do
    it "chains module after itself" do
      expect(graph).to receive(:add_module).with(Hilda::Modules::DebugModule,mod,{test: 'moo'})
      mod.add_module(Hilda::Modules::DebugModule,test: 'moo')
    end
  end

  describe "#add_start_module" do
    it "delegates to graph" do
      expect(graph).to receive(:add_start_module).with(Hilda::Modules::DebugModule,{test: 'moo'})
      mod.add_start_module(Hilda::Modules::DebugModule,test: 'moo')
    end
  end

  describe "#changed? and #changed!" do
    before { mod.instance_variable_set(:@load_change_time, mod.change_time )}
    it "works" do
      expect(mod.changed?).to be_falsy
      mod.changed!
      expect(mod.changed?).to be_truthy
    end
  end

  describe "#reset_module" do
    it "resets run status and output" do
      mod.run_status = :finished
      mod.module_output = {test_out:'test'}
      mod.reset_module
      expect(mod.run_status).to eql :initialized
      expect(mod.module_output).not_to be_present
    end
  end

  describe "#cleanup" do
    it "sets status" do
      mod.cleanup
      expect(mod.run_status).to eql :cleaned
    end
  end

  describe "#rollback" do
    it "calls cleanup and rollback" do
      expect(mod).to receive(:cleanup).and_return(true)
      expect(mod).to receive(:reset_module).and_return(true)
      mod.rollback
    end
  end

  describe "#execute_module" do
    it "calls essential functions and sets status" do
      expect(mod).to receive(:run_module) {
        expect(mod.run_status).to eql :running
        expect(mod.module_output).to eql({})
      }
      expect(graph).to receive(:module_finished).with(mod)
      expect(mod.run_status).to eql :initialized
      mod.execute_module
      expect(mod.run_status).to eql :finished
    end
    it "handles errors" do
      expect(mod).to receive(:run_module) {
        raise 'test error'
      }
      expect(graph).to receive(:module_error).with(mod,an_instance_of(RuntimeError))
      mod.execute_module
      expect(mod.run_status).to eql :error
    end
  end

  describe "serialisation" do
    before {
      mod.run_status = :finished
      mod.module_output = {test_out: 'test'}
    }
    let( :mod2 ) { Hilda::ModuleBase.module_from_json(mod.to_json) }
    it "serialises and deserialises" do
      expect(mod2).to be_a TestModule
      expect(mod2.module_name).to eql mod.module_name
      expect(mod2.param_values[:test_out]).to eql mod.param_values[:test_out]
      expect(mod2.run_status).to eql mod.run_status
      expect(mod2.module_output[:test_out]).to eql mod.module_output[:test_out]
    end
  end
end
