require 'rails_helper'

RSpec.describe Hilda::Modules::FileMetadata do
  let( :graph ) { Hilda::ModuleGraph.new }
  let( :source ) {
    graph.add_start_module(Hilda::Modules::DebugModule, module_output: {
        source_files: {
          'testfile.pdf' => { path: '/tmp/testfile.pdf', original_filename: 'testfile.pdf' },
          'othertestfile.pdf' => { path: '/tmp/othertestfile.pdf', original_filename: 'othertestfile.pdf' }
        }
      }, module_name: 'source')
  }
  let( :metadata_fields) { { title: {label: 'title', type: :string }, other_field: {label: 'test', type: :string, default: 'moo'} } }
  let( :metadata_fields_sanitised ) { { title: {label: 'title', type: :string, default: nil, group: nil}, other_field: {label: 'test', type: :string, default: 'moo', group: nil} } }
  let( :mod ) {
    graph.add_module(Hilda::Modules::FileMetadata, source,
      metadata_fields: metadata_fields)
  }
  before {
    source.run_module
    source.run_status = :finished
  }

  describe "#initialize" do
    it "sets metadata_fields" do
      expect(mod.metadata_fields).to eql( metadata_fields_sanitised )
    end
  end

  describe "#input_changed" do
    it "builds new param defs" do
      expect(mod).to receive(:build_param_defs)
      mod.input_changed
    end

    it "updates timestamp" do
      expect { mod.input_changed }.to change(mod, :change_time)
    end
  end

  describe "#build_param_defs" do
    it "builds correct definitions" do
      mod.build_param_defs
      expect(mod.param_defs).to eql({
        testfile_pdf__title: {
          group: 'testfile.pdf',
          label: 'title',
          type: :string,
          default: nil
        },
        testfile_pdf__other_field: {
          group: 'testfile.pdf',
          label: 'test',
          type: :string,
          default: 'moo'
        },
        othertestfile_pdf__title: {
          group: 'othertestfile.pdf',
          label: 'title',
          type: :string,
          default: nil
        },
        othertestfile_pdf__other_field: {
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

  describe "#autorun?" do
    it "calls ready_to_run?" do
      expect(mod).to receive(:ready_to_run?)
      mod.autorun?
    end
  end

  describe "#run_module" do
    before {
      allow(mod).to receive(:param_values).and_return({
          :'_tmp_testfile_pdf__title' => 'moo',
          :'_tmp_othertestfile_pdf__title' => 'oink'
        })
      allow(mod).to receive(:param_defs).and_return({
          :'_tmp_testfile_pdf__title' => {},
          :'_tmp_othertestfile_pdf__title' => {}
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
          '_tmp_testfile_pdf__title': 'moo',
          '_tmp_othertestfile_pdf__title': 'oink'
        })
    end
  end

end
