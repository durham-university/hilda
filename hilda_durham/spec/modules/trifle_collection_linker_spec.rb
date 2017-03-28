require 'rails_helper'

RSpec.describe HildaDurham::Modules::TrifleCollectionLinker do

  let( :graph ) { Hilda::ModuleGraph.new }
  let( :mod_params ) { {} }
  let( :mod ) { graph.add_start_module(HildaDurham::Modules::TrifleCollectionLinker, mod_params) }

  describe "#query_module" do
    let(:root_collection) { Trifle::API::IIIFCollection.from_json({'title' => 'test collection', 'id' => 'test_col_id', 'sub_collections' => [sub_collection.as_json, sub_collection2.as_json]}) }
    let(:sub_collection) { Trifle::API::IIIFCollection.from_json({'title' => 'test subcollection', 'id' => 'test_subcol_id', 'parent_id' => 'test_col_id'}) }
    let(:sub_collection2) { Trifle::API::IIIFCollection.from_json({'title' => 'test subcollection2', 'id' => 'test_subcol_id2', 'parent_id' => 'test_col_id'}) }

    before {
      allow(Trifle::API::IIIFCollection).to receive(:all).and_return([root_collection])
      allow(Trifle::API::IIIFCollection).to receive(:find).with(root_collection.id).and_return(root_collection)
      allow(Trifle::API::IIIFCollection).to receive(:all_in_collection).with(root_collection).and_return([sub_collection,sub_collection2])
    }

    it "returns a list of repositories" do
      res = mod.query_module({trifle_type: :root_collection})
      expect(res[:status]).to eql 'OK'
      expect(res[:result].length).to eql 1
      expect(res[:result][0]).to eql({'title' => 'test collection', 'id' => 'test_col_id'})
    end

    it "returns a list of sub-collections" do
      res = mod.query_module({trifle_type: :sub_collection, trifle_root_collection: root_collection.id})
      expect(res[:status]).to eql 'OK'
      expect(res[:result].length).to eql 2
      expect(res[:result][0]).to eql({'title' => 'test subcollection', 'id' => 'test_subcol_id'})
    end

    it "returns error when not found" do
      allow(Trifle::API::IIIFCollection).to receive(:find) { raise Trifle::API::FetchError }
      res = mod.query_module({trifle_type: :sub_collection, trifle_root_collection: 'moo'})
      expect(res[:status]).to eql 'ERROR'
      expect(res[:error_message]).to be_present
    end
  end

  describe "#validate_reference" do
    let(:root_collection) { Trifle::API::IIIFCollection.from_json({'title' => 'test collection', 'id' => 'test_col_id', 'sub_collections' => [sub_collection.as_json]}) }
    let(:root_collection2) { Trifle::API::IIIFCollection.from_json({'title' => 'test collection2', 'id' => 'test_col_id2', 'sub_collections' => [sub_collection2.as_json]}) }
    let(:sub_collection) { Trifle::API::IIIFCollection.from_json({'title' => 'test subcollection', 'id' => 'test_subcol_id', 'parent_id' => 'test_col_id'}) }
    let(:sub_collection2) { Trifle::API::IIIFCollection.from_json({'title' => 'test subcollection2', 'id' => 'test_subcol_id2', 'parent_id' => 'test_col_id2'}) }

    before {
      allow(Trifle::API::IIIFCollection).to receive(:all).and_return([root_collection, root_collection2])
      allow(Trifle::API::IIIFCollection).to receive(:find).and_return(nil)
      allow(Trifle::API::IIIFCollection).to receive(:find).with(root_collection.id).and_return(root_collection)
      allow(Trifle::API::IIIFCollection).to receive(:find).with(root_collection2.id).and_return(root_collection2)
      allow(Trifle::API::IIIFCollection).to receive(:find).with(sub_collection.id).and_return(sub_collection)
      allow(Trifle::API::IIIFCollection).to receive(:find).with(sub_collection2.id).and_return(sub_collection2)
      allow(Trifle::API::IIIFCollection).to receive(:all_in_collection).and_return(nil)
      allow(Trifle::API::IIIFCollection).to receive(:all_in_collection).with(root_collection).and_return([sub_collection])
      allow(Trifle::API::IIIFCollection).to receive(:all_in_collection).with(root_collection2).and_return([sub_collection2])

      mod_params[:trifle_root_collection] = root_collection.id
      mod_params[:trifle_sub_collection] = sub_collection.id
    }

    it "returns true with valid reference" do
      expect(mod.validate_reference).to eql true
    end

    it "returns false when object not found" do
      allow(Trifle::API::IIIFCollection).to receive(:find) { raise Trifle::API::FetchError }
      expect(mod.validate_reference).to eql false
    end

    it "returns false when object not set" do
      mod_params[:trifle_root_collection] = nil
      expect(mod.validate_reference).to eql false
    end

    it "allows sub-collection to be nil" do
      mod_params[:trifle_sub_collection] = nil
      expect(mod.validate_reference).to eql true
    end

    it "returns false if sub_collection isn't in the collection" do
      mod_params[:trifle_sub_collection] = sub_collection2.id
      expect(mod.validate_reference).to eql false
    end
    
    it "retries on errors" do
      counter = 0
      expect(mod).to receive(:current_root_collection).once.and_return(root_collection)
      expect(mod).to receive(:current_sub_collection).twice do
        counter += 1
        raise 'Test error' if counter == 1
        sub_collection
      end
      expect(mod.validate_reference).to eql(true)      
    end
  end

  describe "#value_for" do
    it "returns set value" do
      mod_params[:trifle_root_collection] = "test_col"
      expect(mod.value_for(:trifle_root_collection)).to eql 'test_col'
    end
    it "returns empty when value not set" do
      expect(mod.value_for(:trifle_root_collection)).to eql ''
    end
  end

  describe "#label_for" do
    let(:collection) { Trifle::API::IIIFCollection.from_json({'title' => 'test collection', 'id' => 'test_col_id'}) }
    before {
      allow(Trifle::API::IIIFCollection).to receive(:find).with(collection.id).and_return(collection)
    }
    it "returns set label" do
      mod_params[:trifle_root_collection] = collection.id
      expect(mod.label_for(:trifle_root_collection)).to eql 'test collection'
    end
    it "returns empty when value not set" do
      expect(mod.label_for(:trifle_root_collection)).to eql ''
    end
  end

  describe "current objects" do
    let(:root_collection) { Trifle::API::IIIFCollection.from_json({'title' => 'test collection', 'id' => 'test_col_id', 'sub_collections' => [sub_collection.as_json]}) }
    let(:sub_collection) { Trifle::API::IIIFCollection.from_json({'title' => 'test subcollection', 'id' => 'test_subcol_id', 'parent_id' => 'test_col_id'}) }

    before {
      allow(Trifle::API::IIIFCollection).to receive(:find).and_return(nil)
      allow(Trifle::API::IIIFCollection).to receive(:find).with(root_collection.id).and_return(root_collection)
      allow(Trifle::API::IIIFCollection).to receive(:find).with(sub_collection.id).and_return(sub_collection)

      mod_params.merge!({
          trifle_root_collection: root_collection.id,
          trifle_sub_collection: sub_collection.id
        })
    }

    describe "#current_root_collection" do
      it "works" do
        expect(mod.current_root_collection).to eql root_collection
      end
    end
    describe "#current_sub_collection" do
      it "works" do
        expect(mod.current_sub_collection).to eql sub_collection
      end
    end
  end

  describe "#run_module" do
    before {
      mod_params.merge!({
          trifle_root_collection: 'test_col_id',
          trifle_sub_collection: 'test_sub_id'
        })
      mod.module_output={}
      mod.run_status = :running
    }

    it "sets selected sub collection" do
      expect(mod).to receive(:validate_reference).and_return(true)
      mod.run_module
      expect(mod.run_status).to eql :running # graph sets it to finished
      expect(mod.module_output).to eql({ trifle_collection: 'test_sub_id' })
    end
    
    it "sets selected root collection if no sub-collection selected" do
      mod_params[:trifle_sub_collection] = ''
      expect(mod).to receive(:validate_reference).and_return(true)
      mod.run_module
      expect(mod.run_status).to eql :running # graph sets it to finished
      expect(mod.module_output).to eql({ trifle_collection: 'test_col_id' })
    end

    it "validates reference and sets error if invalid" do
      expect(mod).to receive(:validate_reference).and_return(false)
      mod.run_module
      expect(mod.run_status).to eql :error
      expect(mod.module_output).to eql({})
    end
  end

end
