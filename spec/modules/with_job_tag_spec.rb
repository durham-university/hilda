require 'rails_helper'

RSpec.describe Hilda::Modules::WithJobTag do
  before {
    class ModClass
      include Hilda::ModuleBase
      include Hilda::Modules::WithJobTag
    end
  }
  
  let(:mod_params) { {} }
  
  let( :mod ) {
    graph.add_start_module(ModClass,mod_params)
  }
  
  let( :graph ) { Hilda::ModuleGraph.new }

  after { Object.send(:remove_const,:ModClass) }
  
  describe "#execute_moduel" do
    it "sets a job tag" do
      expect(mod).to receive(:run_module).and_return(true)
      expect(mod).to receive(:assign_job_tag)
      mod.execute_module
    end
  end
  
  describe "#assign_job_tag" do 
    it "sets a job tag" do
      mod.assign_job_tag
      expect(mod.job_tag).to be_present
    end
    it "uses graph id if present" do
      class << graph
        def id
          "graph_id"
        end
      end
      mod.assign_job_tag
      expect(mod.job_tag).to match(/^graph_id\/.+/)
    end
    it "doesn't overwrite job_tag" do
      mod.job_tag = "test_tag"
      mod.assign_job_tag
      expect(mod.job_tag).to eql('test_tag')
    end
  end
  
  describe "#as_json" do
    it "includes job_tag in json" do
      mod.assign_job_tag
      expect(mod.as_json[:job_tag]).to eql(mod.job_tag)
    end
  end

  describe "#from_json" do
    it "reads param_defs" do
      mod.assign_job_tag
      expect(ModClass.from_json(mod.to_json).job_tag).to eql(mod.job_tag)
    end
  end

end