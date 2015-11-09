require 'rails_helper'

RSpec.describe HildaDurham::Modules::SchmitLinker do

  let( :graph ) { Hilda::ModuleGraph.new }
  let( :mod_params ) { {} }
  let( :mod ) { graph.add_start_module(HildaDurham::Modules::SchmitLinker, mod_params) }

  describe "#include_fonds?" do
    it "returns true by default" do
      expect(mod.include_fonds?).to eql true
    end
    it "returns false when no_fonds is set" do
      mod_params[:no_fonds] = true
      expect(mod.include_fonds?).to eql false
    end
  end

  describe "#include_catalogue?" do
    it "returns true by default" do
      expect(mod.include_catalogue?).to eql true
    end
    it "returns false when no_catalogue is set" do
      mod_params[:no_catalogue] = true
      expect(mod.include_catalogue?).to eql false
    end
  end

  describe "#query_module" do
    let(:repository) { Schmit::API::Repository.from_json({title: 'test repo', public_id: 'test_repo', id: 'test_repo_id', fonds: [fonds.as_json,fonds2.as_json]}.with_indifferent_access) }
    let(:fonds) { Schmit::API::Fonds.from_json({title: 'test fonds', public_id: 'test_fon', id: 'test_fon_id', catalogues: [catalogue.as_json]}.with_indifferent_access) }
    let(:fonds2) { Schmit::API::Fonds.from_json({title: 'test fonds 2', public_id: 'test_fon2', id: 'test_fon2_id', catalogues: []}.with_indifferent_access) }
    let(:catalogue) { Schmit::API::Catalogue.from_json({title: 'test catalogue', public_id: 'test_cat', id: 'test_cat_id'}.with_indifferent_access) }

    before {
      allow(Schmit::API::Repository).to receive(:all).and_return([repository])
      allow(Schmit::API::Repository).to receive(:find).with(repository.id).and_return(repository)
      allow(Schmit::API::Fonds).to receive(:all_in).with(repository).and_return([fonds,fonds2])
      allow(Schmit::API::Fonds).to receive(:find).with(fonds.id).and_return(fonds)
      allow(Schmit::API::Catalogue).to receive(:all_in).with(repository).and_return([catalogue])
      allow(Schmit::API::Catalogue).to receive(:find).with(catalogue.id).and_return(catalogue)
    }

    it "returns a list of repositories" do
      res = mod.query_module({schmit_type: :repository})
      expect(res[:status]).to eql 'OK'
      expect(res[:result].length).to eql 1
      expect(res[:result][0]).to eql({title: 'test repo', public_id: 'test_repo', id: 'test_repo_id'})
    end

    it "returns a list of fonds" do
      res = mod.query_module({schmit_type: :fonds, schmit_repository: repository.id})
      expect(res[:status]).to eql 'OK'
      expect(res[:result].length).to eql 2
      expect(res[:result][0]).to eql({title: 'test fonds', public_id: 'test_fon', id: 'test_fon_id'})
    end

    it "returns a list of catalogues" do
      res = mod.query_module({schmit_type: :catalogue, schmit_repository: repository.id})
      expect(res[:status]).to eql 'OK'
      expect(res[:result].length).to eql 1
      expect(res[:result][0]).to eql({title: 'test catalogue', public_id: 'test_cat', id: 'test_cat_id'})
    end

    it "returns error when not found" do
      allow(Schmit::API::Repository).to receive(:find) { raise Schmit::API::FetchError }
      res = mod.query_module({schmit_type: :fonds, schmit_repository: 'moo'})
      expect(res[:status]).to eql 'ERROR'
      expect(res[:error_message]).to be_present
    end
  end

  describe "#validate_reference" do
    let(:repository) { Schmit::API::Repository.from_json({title: 'test repo', public_id: 'test_repo', id: 'test_repo_id', fonds: [fonds.as_json]}.with_indifferent_access) }
    let(:other_repository) { Schmit::API::Repository.from_json({title: 'other test repo', public_id: 'test_repo2', id: 'test_repo_id2', fonds: [other_fonds.as_json]}.with_indifferent_access) }
    let(:fonds) { Schmit::API::Fonds.from_json({title: 'test fonds', public_id: 'test_fon', id: 'test_fon_id', parent_id: 'test_repo_id', catalogues: [catalogue.as_json]}.with_indifferent_access) }
    let(:other_fonds) { Schmit::API::Fonds.from_json({title: 'other test fonds', public_id: 'test_fon2', id: 'test_fon_id2', parent_id: 'test_repo_id2', catalogues: [other_catalogue.as_json]}.with_indifferent_access) }
    let(:catalogue) { Schmit::API::Catalogue.from_json({title: 'test catalogue', public_id: 'test_cat', id: 'test_cat_id', parent_id: 'test_fon_id'}.with_indifferent_access) }
    let(:other_catalogue) { Schmit::API::Catalogue.from_json({title: 'other test catalogue', public_id: 'test_cat2', id: 'test_cat_id2', parent_id: 'test_fon_id2'}.with_indifferent_access) }

    before {
      allow(Schmit::API::Repository).to receive(:all).and_return([repository,other_repository])
      allow(Schmit::API::Repository).to receive(:find).and_return(nil)
      allow(Schmit::API::Repository).to receive(:find).with(repository.id).and_return(repository)
      allow(Schmit::API::Repository).to receive(:find).with(other_repository.id).and_return(other_repository)
      allow(Schmit::API::Fonds).to receive(:all_in).and_return(nil)
      allow(Schmit::API::Fonds).to receive(:all_in).with(repository).and_return([fonds])
      allow(Schmit::API::Fonds).to receive(:all_in).with(other_repository).and_return([other_fonds])
      allow(Schmit::API::Fonds).to receive(:find).and_return(nil)
      allow(Schmit::API::Fonds).to receive(:find).with(fonds.id).and_return(fonds)
      allow(Schmit::API::Fonds).to receive(:find).with(other_fonds.id).and_return(other_fonds)
      allow(Schmit::API::Catalogue).to receive(:all_in).and_return(nil)
      allow(Schmit::API::Catalogue).to receive(:all_in).with(repository).and_return([catalogue])
      allow(Schmit::API::Catalogue).to receive(:all_in).with(other_repository).and_return([other_catalogue])
      allow(Schmit::API::Catalogue).to receive(:find).and_return(nil)
      allow(Schmit::API::Catalogue).to receive(:find).with(catalogue.id).and_return(catalogue)
      allow(Schmit::API::Catalogue).to receive(:find).with(other_catalogue.id).and_return(other_catalogue)

      mod_params[:schmit_repository] = repository.id
      mod_params[:schmit_fonds] = fonds.id
      mod_params[:schmit_catalogue] = catalogue.id
    }

    it "returns true with valid reference" do
      expect(mod.validate_reference).to eql true
    end

    it "returns false when object not found" do
      allow(Schmit::API::Repository).to receive(:find) { raise Schmit::API::FetchError }
      expect(mod.validate_reference).to eql false
    end

    it "returns false when object not set" do
      mod_params[:schmit_fonds] = nil
      expect(mod.validate_reference).to eql false
    end

    it "doesn't check existence of fonds if no_fonds is set" do
      mod_params[:no_fonds] = true
      mod_params[:schmit_fonds] = nil
      expect(mod.validate_reference).to eql true
    end

    it "doesn't check existence of catalogue if no_catalogue is set" do
      mod_params[:no_catalogue] = true
      mod_params[:schmit_catalogue] = nil
      expect(mod.validate_reference).to eql true
    end

    it "returns false if fonds isn't in the repository" do
      mod_params[:schmit_fonds] = other_fonds.id
      mod_params[:no_catalogue] = true
      expect(mod.validate_reference).to eql false
    end

    it "returns false if catalogue isn't in the repository" do
      mod_params[:schmit_catalogue] = other_catalogue.id
      mod_params[:no_fonds] = true
      expect(mod.validate_reference).to eql false
    end

    it "returns false if catalogue isn't in the fonds" do
      mod_params[:schmit_catalogue] = other_catalogue.id
      expect(mod.validate_reference).to eql false
    end
  end

  describe "#value_for" do
    it "returns set value" do
      mod_params[:schmit_repository] = "test_repo"
      expect(mod.value_for(:schmit_repository)).to eql 'test_repo'
    end
    it "returns empty when value not set" do
      expect(mod.value_for(:schmit_repository)).to eql ''
    end
  end

  describe "#label_for" do
    let(:repository) { Schmit::API::Repository.from_json({title: 'test repo', public_id: 'test_repo', id: 'test_repo_id', fonds: []}.with_indifferent_access) }
    before {
      allow(Schmit::API::Repository).to receive(:find).with(repository.id).and_return(repository)
    }
    it "returns set label" do
      mod_params[:schmit_repository] = repository.id
      expect(mod.label_for(:schmit_repository)).to eql 'test repo'
    end
    it "returns empty when value not set" do
      expect(mod.label_for(:schmit_repository)).to eql ''
    end
  end

  describe "current objects" do
    let(:repository) { Schmit::API::Repository.from_json({title: 'test repo', public_id: 'test_repo', id: 'test_repo_id', fonds: []}.with_indifferent_access) }
    let(:fonds) { Schmit::API::Fonds.from_json({title: 'test fonds', public_id: 'test_fon', id: 'test_fon_id', catalogues: []}.with_indifferent_access) }
    let(:catalogue) { Schmit::API::Catalogue.from_json({title: 'test catalogue', public_id: 'test_cat', id: 'test_cat_id'}.with_indifferent_access) }

    before {
      allow(Schmit::API::Repository).to receive(:find).with(repository.id).and_return(repository)
      allow(Schmit::API::Fonds).to receive(:find).with(fonds.id).and_return(fonds)
      allow(Schmit::API::Catalogue).to receive(:find).with(catalogue.id).and_return(catalogue)
      mod_params.merge!({
          schmit_repository: repository.id,
          schmit_fonds: fonds.id,
          schmit_catalogue: catalogue.id
        })
    }

    describe "#current_repository" do
      it "works" do
        expect(mod.current_repository).to eql repository
      end
    end
    describe "#current_fonds" do
      it "works" do
        expect(mod.current_fonds).to eql fonds
      end
    end
    describe "#current_catalogue" do
      it "works" do
        expect(mod.current_catalogue).to eql catalogue
      end
    end
  end

  describe "#run_module" do
    before {
      mod_params.merge!({
          schmit_repository: 'test_repo_id',
          schmit_fonds: 'test_fonds_id',
          schmit_catalogue: 'test_catalogue_id'
        })
      mod.module_output={}
      mod.run_status = :running
    }

    it "sets selected reference" do
      expect(mod).to receive(:validate_reference).and_return(true)
      mod.run_module
      expect(mod.run_status).to eql :running # graph sets it to finished
      expect(mod.module_output).to eql({schmit_link: {
          schmit_repository: 'test_repo_id',
          schmit_fonds: 'test_fonds_id',
          schmit_catalogue: 'test_catalogue_id'
        }})
    end

    it "validates reference and sets error if invalid" do
      expect(mod).to receive(:validate_reference).and_return(false)
      mod.run_module
      expect(mod.run_status).to eql :error
      expect(mod.module_output).to eql({})
    end
  end

end
