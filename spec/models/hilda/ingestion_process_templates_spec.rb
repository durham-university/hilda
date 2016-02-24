require 'rails_helper'

RSpec.describe Hilda::IngestionProcessTemplate do
  let(:template) { FactoryGirl.create(:ingestion_process_template,:params) }

  it "is a template" do
    expect(template).to be_a Hilda::IngestionProcessTemplate
  end

  describe "#build_process" do
    let( :graph ) { template.build_process }
    let( :mod_a ) { graph.find_module('mod_a') }
    let( :mod_b ) { graph.find_module('mod_b') }
    it "creates a new process" do
      expect(graph).to be_a Hilda::IngestionProcess
      expect(graph).to be_new_record
    end
    it "copies graph" do
      expect(mod_a).to be_a Hilda::Modules::DebugModule
      expect(mod_b).to be_a Hilda::Modules::DebugModule
      expect(mod_a.param_defs[:moo]).to eql({ label: 'moo', type: :string, default: nil, group: nil, collection: nil, optional: false })
      expect(mod_a.param_defs[:baa]).to eql({ label: 'baa', type: :string, default: 'baa', group: nil, collection: nil, optional: false })
      expect(mod_b.param_defs).to eql({})
      expect(graph.module_source(mod_b)).to eql mod_a
      expect(graph.start_modules).to eql [mod_a]
    end
    it "sets title" do
      expect(graph.title).to be_present
    end
  end
end
