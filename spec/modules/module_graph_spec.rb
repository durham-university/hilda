require 'rails_helper'

RSpec.describe Hilda::ModuleGraph do
  before {
    class TestModule
      include Hilda::ModuleBase
      def run_module
        module_output = param_values.fetch(:output,{ test_out: 'test' })
      end
      def autorun?
        param_values.fetch(:autorun,true)
      end
    end
  }

  #
  # mod_a -> mod_b -> mod_c
  #       -> mod_d -> mod_e -> mod_f
  # mod_g
  #
  # B and C not autorun
  #

  let!( :mod_a ) { graph.add_start_module(TestModule,'mod_a') }
  let!( :mod_b ) { graph.add_module(TestModule,'mod_b',mod_a, autorun: false) }
  let!( :mod_c ) { graph.add_module(TestModule,'mod_c','mod_b') }
  let!( :mod_d ) { graph.add_module(TestModule,'mod_d',mod_a) }
  let!( :mod_e ) { graph.add_module(TestModule,'mod_e',mod_d, autorun: false) }
  let!( :mod_f ) { graph.add_module(TestModule,'mod_f',mod_e) }
  let!( :mod_g ) { graph.add_start_module(TestModule,'mod_g') }

  let!( :graph ) { Hilda::ModuleGraph.new }

  after{ Object.send(:remove_const, :TestModule) }

  describe "#module_source" do
    it "gets returns nil for start modules" do
      expect(graph.module_source(mod_a)).to be_nil
    end
    it "gets the correct source for modules" do
      expect(graph.module_source(mod_b)).to eql mod_a
      expect(graph.module_source(mod_c)).to eql mod_b
      expect(graph.module_source(mod_e)).to eql mod_d
    end
  end

  describe "#find_module" do
    it "finds the module" do
      expect(graph.find_module('mod_d')).to eql mod_d
    end
    it "retruns nil if module doesn't exist" do
      expect(graph.find_module('test')).to be_nil
    end
  end

  describe "#run_status" do
    it "returns :initialized when all initialized" do
      expect(graph.run_status).to eql :initialized
    end
    it "returns :error when any has error" do
      mod_b.run_status=:error
      mod_a.run_status=:finished
      mod_c.run_status=:cleaned
      expect(graph.run_status).to eql :error
    end
    it "returns :finished when all finished" do
      [mod_a, mod_b, mod_c, mod_d, mod_e, mod_f, mod_g].each do |mod| mod.run_status=:finished end
      expect(graph.run_status).to eql :finished
    end
    it "returns :cleaned when all cleaned" do
      [mod_a, mod_b, mod_c, mod_d, mod_e, mod_f, mod_g].each do |mod| mod.run_status=:cleaned end
      expect(graph.run_status).to eql :cleaned
    end
    it "returns :running when something is running" do
      mod_b.run_status=:error
      mod_a.run_status=:finished
      mod_c.run_status=:running
      expect(graph.run_status).to eql :running
    end
    it "returns :paused if some have finished" do
      mod_a.run_status=:finished
      expect(graph.run_status).to eql :paused
    end
  end

  describe "#input_for" do
    it "returns empty hash for start modules" do
      expect(graph.input_for(mod_a)).to eql({})
    end
    it "raises an error if input module hasn't been ran yet" do
      expect{ graph.input_for(mod_b) }.to raise_error('Source module not finished')
    end
    it "gets input correctly" do
      mod_a.run_status = :finished
      mod_a.module_output = { test_out: 'test' }
      expect(graph.input_for(mod_b)).to eql({ test_out: 'test' })
    end
    it "accepts module name" do
      mod_a.run_status = :finished
      mod_a.module_output = { test_out: 'test' }
      expect(graph.input_for('mod_b')).to eql({ test_out: 'test' })
    end
  end

  describe "#add_start_module" do
    it "has start module set" do
      expect(graph.start_modules).to eql [mod_a, mod_g]
    end
  end

  describe "#add_module" do
    it "has all graph data" do
      expect(graph.graph.keys).to eql [mod_a, mod_b, mod_c, mod_d, mod_e, mod_f, mod_g]
      expect(graph.graph[mod_a]).to eql [mod_b, mod_d]
    end
    it "passes params" do
      expect(mod_b.param_values[:autorun]).to eql false
    end
  end

  describe "#reset_graph" do
    it "resets all modules" do
      [mod_a, mod_b, mod_c, mod_d, mod_e, mod_f, mod_g].each do |mod|
        expect(mod).to receive(:reset_module)
      end
      graph.reset_graph
    end
  end

  describe "#rollback_graph" do
    it "roll back finished mods in revers order" do
      [mod_a, mod_b, mod_c, mod_d, mod_g].each do |mod|
        mod.run_status = :finished
        expect(mod).to receive(:rollback) {
          mod.module_graph.graph[mod].each do |n|
            expect(n.run_status).to eql :initialized
          end
          mod.run_status = :initialized
        }
      end
      expect(mod_e).to receive(:rollback)
      expect(mod_f).not_to receive(:rollback)
      graph.rollback_graph
    end
  end

  describe "#start_graph" do
    it "resets the graph" do
      expect(graph).to receive(:reset_graph)
      graph.start_graph
    end
    it "starts execution from start modules" do
      expect(mod_a).to receive(:execute_module)
      expect(mod_g).to receive(:execute_module)
      expect(mod_b).not_to receive(:execute_module)
      expect(mod_d).not_to receive(:execute_module)
      graph.start_graph
    end
    it "calls stop event" do
      expect(graph).to receive(:graph_stopped)
      graph.start_graph
    end
  end

  describe "#finished?" do
    it "returns false when not finished" do
      expect(graph.finished?).to eql false
      # all but mod_f
      [mod_a, mod_b, mod_c, mod_d, mod_e, mod_g].each do |mod| mod.run_status=:finished end
      expect(graph.finished?).to eql false
    end
    it "returns true when all finished" do
      [mod_a, mod_b, mod_c, mod_d, mod_e, mod_f, mod_g].each do |mod| mod.run_status=:finished end
      expect(graph.finished?).to eql true
    end
  end

  describe "#continue_execution" do
    it "continues execution" do
      [mod_a, mod_b, mod_d].each do |mod| mod.run_status=:finished end
      [mod_c, mod_e, mod_g].each do |mod| expect(mod).to receive(:execute_module) end
      expect(mod_f).not_to receive(:execute_module)
      graph.continue_execution
    end
    it "calls stop event" do
      expect(graph).to receive(:graph_stopped)
      graph.continue_execution
    end
  end

  describe "#module_finished" do
    it "calls next autorun modules" do
      expect(mod_b).not_to receive(:execute_module)
      expect(mod_d).to receive(:execute_module)
      graph.module_finished(mod_a)
    end
  end

  describe "#graph_stopped" do
    it "calls graph_finished if all finished" do
      expect(graph).to receive(:finished?).and_return(true)
      expect(graph).to receive(:graph_finished)
      graph.graph_stopped
    end
    it "doesn't call graph_finished if not everything is finished" do
      expect(graph).to receive(:finished?).and_return(false)
      expect(graph).not_to receive(:graph_finished)
      graph.graph_stopped
    end
  end

  describe "serialisation" do
    before {
      [mod_a, mod_b, mod_d].each do |mod| mod.run_status=:finished end
    }
    let( :graph2 ) { Hilda::ModuleGraph.from_json(graph.to_json) }
    it "serialises and deserialises" do
      expect(graph2).to be_a Hilda::ModuleGraph
      expect(graph2.graph.size).to eql graph.graph.size
      ['mod_a', 'mod_b', 'mod_d'].each do |mod|
        expect(graph2.find_module(mod).run_status).to eql :finished
      end
      ['mod_c', 'mod_e', 'mod_g'].each do |mod|
        expect(graph2.find_module(mod).run_status).to eql :initialized
        expect(graph2.find_module(mod)).to receive(:execute_module)
      end
      expect(graph2.find_module('mod_f')).not_to receive(:execute_module)
      expect(graph2).to receive(:graph_stopped)
      graph2.continue_execution
    end
    it "only serialises each module once" do
      expect(mod_a).to receive(:as_json).once.and_call_original
      expect(mod_b).to receive(:as_json).once.and_call_original
      expect(mod_c).to receive(:as_json).once.and_call_original
      graph2 # serialise by reference
    end
  end
end