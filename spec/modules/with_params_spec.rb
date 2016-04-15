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
    :'te/st' => {label: 'test', type: :string, default: 'moo' },
    options: {label: 'options', type: :select, collection: ['aaa','bbb'], note: 'param note'},
    optional_param: {label: 'optional', type: :string, optional: true}
  } }
  let( :param_defs_sanitised ) { {
    title: {label: 'title', type: :string, default: nil, group: nil, optional: false, collection: nil, note: nil },
    :'te/st' => {label: 'test', type: :string, default: 'moo', group: nil, optional: false, collection: nil, note: nil },
    options: {label: 'options', type: :select, default: nil, group: nil, optional: false, collection: ['aaa','bbb'], note: 'param note'},
    optional_param: {label: 'optional', type: :string, default: nil, group: nil, optional: true, collection: nil, note: nil}
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
      mod.receive_params({'title' => 'new title', 'te/st' => 'new test', 'other' => 'something else'})
      expect( mod.param_values ).to eql({title: 'new title', :'te/st' => 'new test'})
    end
    it "calls changed!" do
      expect(mod).to receive(:changed!)
      mod.receive_params({'title' => 'new title', 'te/st' => 'new test', 'other' => 'something else'})
    end
    it "returns true" do
      ret = mod.receive_params({'title' => 'new title', 'te/st' => 'new test', 'other' => 'something else'})
      expect( ret ).to eql true
    end
    it "doesn't take in params if module cannot receive params" do
      expect(mod).to receive(:can_receive_params?).and_return(false)
      expect{
        mod.receive_params({'title' => 'new title', 'te/st' => 'new test', 'other' => 'something else'})
      }.to raise_error("Module cannot receive params in current state")
    end
  end

  describe "#all_params_valid?" do
    it "returns false if something's not valid" do
      mod.param_values[:title] = ''
      expect(mod.all_params_valid?).to eql false
      mod.param_values[:title] = nil
      expect(mod.all_params_valid?).to eql false
    end
    it "returns true when everything's present" do
      expect(mod).to receive(:validate_param).at_least(:once).and_call_original
      mod.param_values[:title] = 'new title'
      mod.param_values[:te_st] = 'new test'
      mod.param_values[:options] = 'aaa'
      mod.param_values[:optional_param] = 'aaa'
      expect(mod.all_params_valid?).to eql true
    end
    it "returns true if only optional params are missing" do
      expect(mod).to receive(:validate_param).at_least(:once).and_call_original
      mod.param_values[:title] = 'new title'
      mod.param_values[:te_st] = 'new test'
      mod.param_values[:options] = 'aaa'
      expect(mod.all_params_valid?).to eql true
    end
    it "returns true when a param only has a default value" do
      expect(mod).to receive(:validate_param).at_least(:once).and_call_original
      mod.param_values[:title] = 'new title'
      mod.param_values[:optional_param] = 'aaa'
      mod.param_values[:options] = 'aaa'
      expect(mod.all_params_valid?).to eql true
      mod.param_values[:te_st] = ''
      expect(mod.all_params_valid?).to eql true
      mod.param_values[:te_st] = nil
      expect(mod.all_params_valid?).to eql true
    end
  end
  
  describe "#ready_to_run?" do
    it "returns true when params are valid" do
      expect(mod).to receive(:all_params_valid?).and_return(true)
      expect(mod.ready_to_run?).to eql(true)
    end
    it "returns false when params are not valid" do
      expect(mod).to receive(:all_params_valid?).and_return(false)
      expect(mod.ready_to_run?).to eql(false)
    end
  end

  describe "#validate_param" do
    it "returns true if present" do
      expect(mod.validate_param(:title,'value')).to eql true
    end
    it "returns false if not present" do
      expect(mod.validate_param(:title,'')).to eql false
      expect(mod.validate_param(:title,nil)).to eql false
    end
    it "returns true if optional and not present" do
      expect(mod.validate_param(:optional_param,nil)).to eql true
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
      expect(mod.submitted_params).to eql({title: 'title_test', :'te/st' => 'moo'})
    end
  end
  
  describe "#check_submitted_status!" do
    it "changes to :submitted if all params valid" do
      expect(mod).to receive(:all_params_valid?).and_return(true)
      mod.run_status = :initialized
      mod.check_submitted_status!
      expect(mod.run_status).to eql(:submitted)
    end
    it "changes to :initialized if params not valid" do
      expect(mod).to receive(:all_params_valid?).and_return(false)
      mod.run_status = :submitted
      mod.check_submitted_status!
      expect(mod.run_status).to eql(:initialized)
    end
    it "doesn't change status when not submitted or initialized" do
      expect(mod).to receive(:all_params_valid?).and_return(false)
      mod.run_status = :error
      mod.check_submitted_status!
      expect(mod.run_status).to eql(:error)
    end
  end

  describe "sanitise_field_defs" do
    it "sanitises param defs" do
      expect(mod.param_defs).to eql param_defs_sanitised
    end
  end
  
  describe "#run_module" do
    it "merges submitted params" do
      expect(mod).to receive(:all_params_valid?).and_return(true)
      expect(mod).to receive(:module_input).and_return({foo: 'aaa', submitted_params: { bar: 'bbb' }})
      expect(mod).to receive(:submitted_params).and_return({moo: 'ccc', oink: 'ddd'})
      mod.run_module
      expect(mod.module_output).to eql({foo: 'aaa', submitted_params: {bar: 'bbb', moo: 'ccc', oink: 'ddd'}})
    end
    it "stops if params aren't valid" do
      expect(mod).to receive(:all_params_valid?).and_return(false)
      mod.run_module
      expect(mod.run_status).to eql(:error)
    end
  end

end
