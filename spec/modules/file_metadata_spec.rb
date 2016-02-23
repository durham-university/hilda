require 'rails_helper'

RSpec.describe Hilda::Modules::FileMetadata do
  let( :file_names ) { ['testfile.pdf','othertestfile.pdf'] }
  let( :graph ) { 
    Hilda::ModuleGraph.new.tap do |graph| 
      graph[:source_file_names] = file_names
    end 
  }
  let( :metadata_fields) { { title: {label: 'title', type: :string }, other_field: {label: 'test', type: :string, default: 'moo'} } }
  let( :metadata_fields_sanitised ) { { title: {label: 'title', type: :string, default: nil, group: nil}, other_field: {label: 'test', type: :string, default: 'moo', group: nil} } }
  let( :mod ) {
    graph.add_start_module(Hilda::Modules::FileMetadata, metadata_fields: metadata_fields)
  }

  describe "#initialize" do
    it "sets metadata_fields" do
      expect(mod.metadata_fields).to eql( metadata_fields_sanitised )
    end
  end

  describe "#graph_params_changed" do
    it "builds new param defs" do
      expect(mod).to receive(:build_param_defs)
      mod.graph_params_changed
    end

    it "updates timestamp" do
      expect { mod.graph_params_changed }.to change(mod, :change_time)
    end
  end

  describe "#build_param_defs" do
    it "works with nil input" do
      graph[:source_file_names] = nil
      expect { mod.build_param_defs }.not_to raise_error
      expect(mod.param_defs).to eql({})
    end
    it "builds correct definitions" do
      mod.build_param_defs
      expect(mod.param_defs).to eql({
        :'testfile.pdf__title' => {
          group: 'testfile.pdf',
          label: 'title',
          type: :string,
          default: nil
        },
        :'testfile.pdf__other_field' => {
          group: 'testfile.pdf',
          label: 'test',
          type: :string,
          default: 'moo'
        },
        :'othertestfile.pdf__title' => {
          group: 'othertestfile.pdf',
          label: 'title',
          type: :string,
          default: nil
        },
        :'othertestfile.pdf__other_field' => {
          group: 'othertestfile.pdf',
          label: 'test',
          type: :string,
          default: 'moo'
        }
      })
    end
  end

  describe "#as_json" do
    it "includes metadata_fields in json" do
      expect(mod.as_json[:metadata_fields]).to eql metadata_fields_sanitised
    end
  end

  describe "#from_json" do
    it "reads metadata_fields" do
      expect(Hilda::Modules::FileMetadata.from_json(mod.to_json).metadata_fields).to eql metadata_fields_sanitised
    end
  end

  describe "#run_module" do
    before {
      allow(mod).to receive(:param_values).and_return({
          :'/tmp/testfile.pdf__title' => 'moo',
          :'/tmp/othertestfile.pdf__title' => 'oink'
        })
      allow(mod).to receive(:param_defs).and_return({
          :'/tmp/testfile.pdf__title' => {},
          :'/tmp/othertestfile.pdf__title' => {}
        })
      mod.module_output = {}
    }
    it "won't run without all values" do
      expect(mod).to receive(:all_params_valid?).and_return(false)
      mod.run_module
      expect(mod.run_status).to eql :error
      expect(mod.module_output).to be_empty
    end

    it "sets param_values if they're set" do
      expect(mod).to receive(:all_params_valid?).and_return(true)
      mod.run_module
      expect(mod.run_status).not_to eql :error
      expect(mod.module_output[:file_metadata]).to eql({
          '/tmp/testfile.pdf__title': 'moo',
          '/tmp/othertestfile.pdf__title': 'oink'
        })
    end
  end

end
