require 'rails_helper'

RSpec.describe 'WithUser' do
  before {
    class FooJob
      include Hilda::Jobs::JobBase
      include Hilda::Jobs::WithUser
    end
    raise "User already defined" if defined?(User)
    class User
      def self.find_by_user_key(key)
      end
    end
  }
  after {
    Object.send(:remove_const,:FooJob)
    Object.send(:remove_const,:User)
  }
  let!( :user ) {
    double('user').tap do |user|
      allow(user).to receive(:user_key).and_return('foouser')
      allow(User).to receive(:find_by_user_key).with('foouser').and_return(user)
    end
  }
  let( :job ) { FooJob.new(user: 'foouser') }

  describe "#user" do
    it "finds the user" do
      expect(job.user).to eql user
    end
  end

  describe "marhsalling" do
    let( :dump ) { Marshal.dump(job) }
    let( :loaded ) { Marshal.load( dump ) }
    describe "dumping" do
      it "should dump the object" do
        expect(dump).to be_present
      end
    end

    describe "loading" do
      it "loads the object" do
        expect(loaded).to be_a FooJob
        expect(loaded.user_key).to eql 'foouser'
      end
    end
  end

end
