require 'rails_helper'

RSpec.describe Hilda::IngestionProcess do

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

  let( :mod_a ) { graph_only.add_start_module(TestModule, module_name: 'mod_a') }
  let( :mod_b ) { graph_only.add_module(TestModule, mod_a, module_name: 'mod_b', autorun: false) }
  let( :mod_c ) { graph_only.add_module(TestModule, mod_b, module_name: 'mod_c') }
  let( :mod_d ) { graph_only.add_module(TestModule, mod_a, module_name: 'mod_d') }
  let( :mod_e ) { graph_only.add_module(TestModule, mod_d, module_name: 'mod_e', autorun: false) }
  let( :mod_f ) { graph_only.add_module(TestModule, mod_e, module_name: 'mod_f') }
  let( :mod_g ) { graph_only.add_start_module(TestModule, module_name: 'mod_g') }
  let( :all_modules ) { [mod_a, mod_b, mod_c, mod_d, mod_e, mod_f, mod_g] }
  let( :graph_only ) { Hilda::IngestionProcess.new }
  let( :graph ) { all_modules ; graph_only }
  let( :process ) { graph }

  describe "persisting graph" do
    before {
      mod_a.run_status = :finished
      mod_a.log! 'Test log message'
      mod_b.run_status = :finished
      process.save
    }
    let( :loaded ) { Hilda::IngestionProcess.find(process.id) }
    it "loads form fedora" do
      expect(loaded).to be_a Hilda::IngestionProcess
      expect(loaded.graph.size).to eql 7
      expect(loaded.run_status).to eql :paused
      expect(loaded.find_module('mod_a').run_status).to eql :finished
      expect(loaded.find_module('mod_a').log.first.message).to eql 'Test log message'
    end
    it "can be updated and reloaded" do
      loaded.log! "Another message"
      loaded.find_module('mod_b').run_status = :error
      loaded.save
      loaded.reload
      expect(loaded.log.last.message).to eql 'Another message'
      expect(loaded.run_status).to eql :error
    end

    it "can load and persist really big graphs" do
      100.times do |i|
        mod_a.log! "Dummy log message #{i}"
      end
      expect(process.to_json.length).to be > 5000
      process.save
      expect(process.module_graph_serialisation.size).to be > 1
      expect(loaded).to be_a Hilda::IngestionProcess
      expect(loaded.graph.size).to eql 7
      expect(loaded.run_status).to eql :paused
      expect(loaded.find_module('mod_a').run_status).to eql :finished
      expect(loaded.find_module('mod_a').log.map(&:message)).to eql(mod_a.log.map(&:message))
      loaded.find_module('mod_c').run_status = :finished
      loaded.save
      expect(loaded.reload.find_module('mod_c').run_status).to eql :finished
    end
  end

  describe "autosaving" do
    describe "#set_last_saved" do
      it "sets last_saved" do
        process.last_saved = 0
        process.send(:set_last_saved)
        expect(process.last_saved).to be_within(1000).of(DateTime.now.to_f*1000)
      end
    end

    describe "#autosave" do
      before{ process.send(:set_last_saved) }
      it "saves when graph changed" do
        expect(process).to receive(:change_time).and_return(process.last_saved+1000)
        expect(process).to receive(:save)
        process.autosave
      end
      it "doesn't save when graph not changed" do
        expect(process).to receive(:change_time).and_return(process.last_saved)
        expect(process).not_to receive(:save)
        process.autosave
      end
    end

    describe "#graph_stopped" do
      it "calls #autosave" do
        expect(process).to receive(:autosave)
        process.graph_stopped
      end
    end
    describe "#graph_finished" do
      it "calls #autosave" do
        expect(process).to receive(:autosave)
        process.graph_finished
      end
    end
    describe "#module_finished" do
      it "calls #autosave" do
        expect(process).to receive(:autosave)
        process.module_finished(mod_a,false)
      end
    end
    describe "#module_starting" do
      it "calls #autosave" do
        expect(process).to receive(:autosave)
        process.module_starting(mod_a)
      end
    end

    it "sets last_saved when saving" do
      expect(process).to receive(:set_last_saved)
      process.save
    end

    it "sets last_saved when loading" do
      process.save
      expect_any_instance_of(Hilda::IngestionProcess).to receive(:set_last_saved).and_call_original
      expect(Hilda::IngestionProcess.first.last_saved).to be_within(1000).of(DateTime.now.to_f*1000)
    end
  end


end
