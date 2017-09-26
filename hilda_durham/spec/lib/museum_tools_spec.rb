require 'rails_helper'

RSpec.describe HildaDurham::MuseumTools do
  def make_file_list(file_names)
    file_names.each_with_object({}) do |file_name,map|
      file_name = "#{map.count+1}_#{file_name}.jpg"
      map[file_name] = {original_filename: file_name}
    end
  end
  def get_suffixes(file_list)
    re = /^.*[_ -]([a-z0-9]+)\.jpg/
    file_list.keys.map do |file_name|
      re.match(file_name)[1]
    end
  end
  
  def sorted_suffixes(file_names)
    get_suffixes(tools.sort(make_file_list(file_names)))
  end
  
  let(:tools) { HildaDurham::MuseumTools }
  
  describe "#sort" do
    it "sorts files" do
      expect(sorted_suffixes(['ff','q1','rr','q2','bb','q3','ll','q4','tt','uu','gg','d1','d2','fx','bx','lx','rx','tx','ux','pc1','pc2','other1','other2'])).to eql(['ff','q1','rr','q2','bb','q3','ll','q4','tt','uu','gg','d1','d2','fx','bx','lx','rx','tx','ux','pc1','pc2','other1','other2'])
      expect(sorted_suffixes(['other','ll','rr','ff','bb','q1','q4','fx'])).to eql(['ff','q1','rr','bb','ll','q4','fx','other'])
      expect(sorted_suffixes(['ll'])).to eql(['ll'])
    end
  end
  
  describe "#set_default_values" do
    let(:mod) { double('mod', groups: [], data_key: :bulk_data)}
    
    it "sets default values" do
      all_suffixes = ['ff','q1','rr','q2','bb','q3','ll','q4','tt','uu','gg','d1','d2','fx','bx','lx','rx','tx','ux','pc1','pc2','other1','other2'] \
                        .map do |s| "file_#{s}.jpg" end
      mod.groups.concat(all_suffixes)
      expect(tools.set_default_values(mod)[:bulk_data]).to eql("front\nquarter 1\nright\nquarter 2\nback\nquarter 3\nleft\nquarter 4\ntop\nunderside\ngroup\ndetail 1\ndetail 2\nfront inscription\nback inscription\nleft inscription\nright inscription\ntop inscription\nunderside inscription\npost conservation image 1\npost conservation image 2\n\n")
      mod.groups.clear
      mod.groups.concat(['1_ll.jpg','2_d1.jpg'])
      expect(tools.set_default_values(mod)[:bulk_data]).to eql("left\ndetail 1")
      mod.groups.clear
      expect(tools.set_default_values(mod)[:bulk_data]).to eql("")
    end
  end

end