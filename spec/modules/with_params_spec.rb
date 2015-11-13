require 'rails_helper'

RSpec.describe Hilda::Modules::WithParams do
  before {
    class ModClass
      include Hilda::ModuleBase
      include Hilda::Modules::WithParams
    end
  }
  let( :param_defs ) { {
    title: {label: 'title', type: :string },
    :'te/st' => {label: 'test', type: :string, default: 'moo' }
  } }
  let( :param_defs_sanitised ) { {
    title: {label: 'title', type: :string, default: nil, group: nil },
    te_st: {label: 'test', type: :string, default: 'moo', group: nil }
  } }
  let( :mod ) {
    graph.add_start_module(ModClass).tap do |mod|
      mod.param_defs = ModClass.sanitise_field_defs( param_defs )
      mod.module_output = {}
    end
  }
  let( :graph ) { Hilda::ModuleGraph.new }

  after { Object.send(:remove_const,:ModClass) }

  describe "#receive_params" do
    it "sets only defined params" do
      mod.receive_params({'title' => 'new title', 'te_st' => 'new test', 'other' => 'something else'})
      expect( mod.param_values ).to eql({title: 'new title', te_st: 'new test'})
    end
    it "calls changed!" do
      expect(mod).to receive(:changed!)
      mod.receive_params({'title' => 'new title', 'te_st' => 'new test', 'other' => 'something else'})
    end
    it "returns true" do
      ret = mod.receive_params({'title' => 'new title', 'te_st' => 'new test', 'other' => 'something else'})
      expect( ret ).to eql true
    end
    it "doesn't take in params if module cannot receive params" do
      expect(mod).to receive(:can_receive_params?).and_return(false)
      expect{
        mod.receive_params({'title' => 'new title', 'te_st' => 'new test', 'other' => 'something else'})
      }.to raise_error("Module cannot receive params in current state")
    end
  end

  describe "#all_params_valid?" do
    it "returns false if something's not valid" do
      expect(mod).to receive(:validate_param).at_least(:once).and_call_original
      mod.param_values[:title] = 'new title'
      expect(mod.all_params_valid?).to eql false
      mod.param_values[:te_st] = ''
      expect(mod.all_params_valid?).to eql false
    end
    it "returns true when everything's present" do
      expect(mod).to receive(:validate_param).at_least(:once).and_call_original
      mod.param_values[:title] = 'new title'
      mod.param_values[:te_st] = 'new test'
      expect(mod.all_params_valid?).to eql true
    end
  end

  describe "#validate_param" do
    it "returns true if present" do
      expect(mod.validate_param('aa','value')).to eql true
    end
    it "returns false if now present" do
      expect(mod.validate_param('aa','')).to eql false
      expect(mod.validate_param('aa',nil)).to eql false
    end
  end

  describe "#as_json" do
    it "includes param_defs in json" do
      expect(mod.as_json[:param_defs]).to eql param_defs_sanitised
    end
  end

  describe "#from_json" do
    it "reads param_defs" do
      expect(ModClass.from_json(mod.to_json).param_defs).to eql param_defs_sanitised
    end
  end

  describe "#submitted_params" do
    it "returns only defined params" do
      mod.param_values.merge!({title: 'title_test', other: 'other_test' })
      expect(mod.submitted_params).to eql({title: 'title_test'})
    end
  end

  describe "sanitise_field_defs" do
    it "sanitises param defs" do
      expect(mod.param_defs).to eql param_defs_sanitised
    end
  end

end
