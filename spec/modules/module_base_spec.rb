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
    let( :disabled_mod ) { graph.add_start_module(TestModule, module_name: 'module name', optional_module: true, default_disabled: true ) }
    it "sets initial values" do
      expect(mod.module_name).to eql 'module_name'
      expect(mod.run_status).to eql :initialized
      expect(mod.log).not_to be_nil
      expect(mod.module_graph).to be_a Hilda::ModuleGraph
      expect(mod.param_values[:test_out]).to eql 'test'
    end
    
    it "sets disabled if :default_disabled is true" do
      expect(disabled_mod.run_status).to eql :disabled
    end
  end
  
  describe "#set_disabled" do
    it "raises error if not optional module" do
      expect {
        mod.set_disabled(true)
      } .to raise_error('Cannot disable a non-optional module')
      expect(mod.run_status).not_to eql(:disabled)
    end
    it "set disabled module if it is optional" do
      mod.param_values[:optional_module]=true
      expect(mod).to receive(:changed!)
      mod.set_disabled(true)
      expect(mod.run_status).to eql(:disabled)
    end
    it "enables module" do
      mod.run_status=:disabled
      expect(mod).to receive(:reset_module).and_call_original
      expect(mod).to receive(:changed!).at_least(:once)
      mod.set_disabled(false)
      expect(mod.run_status).to eql(:initialized)
    end
  end
  
  describe "#disable!" do
    it "calls set_disabled" do
      expect(mod).to receive(:set_disabled).with(true)
      mod.disable!
    end
  end
  
  describe "#enable!" do
    it "calls set_disabled" do
      expect(mod).to receive(:set_disabled).with(false)
      mod.enable!
    end
  end
  
  describe "#disabled?" do
    it "checks run_status==:disabled" do
      mod.run_status = :disabled
      expect(mod.disabled?).to eql(true)
      mod.run_status = :initialized
      expect(mod.disabled?).to eql(false)
    end
  end
  
  describe "#optional?" do
    it "checks :optional_module in params" do
      expect(mod.optional?).to eql(false)
      mod.param_values[:optional_module]=true
      expect(mod.optional?).to eql(true)
    end
  end

  describe "#rendering_option and #set_rendering_option" do
    it "can set and get values" do
      expect(mod.rendering_option(:test)).to be_nil
      mod.set_rendering_option(:test,'moo')
      expect(mod.rendering_option(:test)).to eql 'moo'
    end
    it "stores options in param_values" do
      mod.set_rendering_option(:test,'moo')
      mod.set_rendering_option(:test2,'baa')
      expect(mod.param_values[:rendering_options]).to eql({test: 'moo', test2: 'baa'})
    end
  end

  describe "#can_receive_params?" do
    before {
      class TestModule
        include Hilda::Modules::WithParams
      end
    }
    it "works" do
      mod.run_status=:running
      expect(mod.can_receive_params?).to eql false
      mod.run_status=:finished
      expect(mod.can_receive_params?).to eql false
      mod.run_status=:initialized
      expect(mod.can_receive_params?).to eql true
      allow(graph).to receive(:run_status).and_return(:running)
      expect(mod.can_receive_params?).to eql false
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
    it "resets run status and output and calls changed!" do
      mod.run_status = :finished
      mod.module_output = {test_out:'test'}
      expect(mod).to receive(:changed!).at_least(:once)
      mod.reset_module
      expect(mod.run_status).to eql :initialized
      expect(mod.module_output).not_to be_present
    end
    it "keeps disabled modules disabled" do
      mod.run_status = :disabled
      mod.module_output = {test_out:'test'}
      mod.reset_module
      expect(mod.run_status).to eql :disabled
      expect(mod.module_output).not_to be_present
    end
  end

  describe "#cleanup" do
    it "sets status and calls changed!" do
      expect(mod).to receive(:changed!)
      mod.cleanup
      expect(mod.run_status).to eql :cleaned
    end
    it "keeps disabled modules disabled" do
      mod.run_status = :disabled
      mod.cleanup
      expect(mod.run_status).to eql :disabled
    end
  end

  describe "#rollback" do
    it "calls cleanup and rollback" do
      expect(mod).to receive(:cleanup).and_return(true)
      expect(mod).to receive(:reset_module).and_return(true)
      mod.rollback
    end
  end
  
  describe "#autorun?" do
    it "returns true if run_status is :submitted" do
      mod.run_status = :submitted
      expect(mod.autorun?).to eql(true)
    end
    it "returns false unles run_status is :submitted" do
      expect(mod.autorun?).to eql(false)
    end
  end  
  
  describe "#ready_to_run?" do
    it "returns false if isn't in a suitable state" do
      expect(graph).not_to receive(:module_source)
      [:finished, :cleaned, :disabled].each do |status|
        mod.run_status = status
        expect(mod.ready_to_run?).to eql(false)
      end
    end
    
    it "returns false if source hasn't been run" do
      expect(graph).to receive(:module_source).and_return(double('mock module', run_status: :submitted, module_output: nil))
      expect(mod.ready_to_run?).to eql(false)
    end
    
    it "returns true if source has been run" do
      expect(graph).to receive(:module_source).and_return(double('mock module', run_status: :finished, module_output: { foo: 'moo' }))
      expect(mod.ready_to_run?).to eql(true)
    end
    
    it "returns true if nil source" do
      expect(graph).to receive(:module_source).and_return(nil)
      expect(mod.ready_to_run?).to eql(true)
    end
  end

  describe "#execute_module" do
    it "calls essential functions and sets status" do
      expect(mod).to receive(:ready_to_run?).and_return(true)
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
