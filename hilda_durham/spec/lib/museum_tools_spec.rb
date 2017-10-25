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
      expect(sorted_suffixes(['ff','q1','ll','q2','bb','q3','rr','q4','tt','uu','gg','d1','d2','fx','bx','lx','rx','tx','ux','pc1','pc2','other1','other2'])).to eql(['ff','q1','ll','q2','bb','q3','rr','q4','tt','uu','gg','d1','d2','fx','bx','lx','rx','tx','ux','pc1','pc2','other1','other2'])
      expect(sorted_suffixes(['other','rr','ll','ff','bb','q1','q4','fx'])).to eql(['ff','q1','ll','bb','rr','q4','fx','other'])
      expect(sorted_suffixes(['ll'])).to eql(['ll'])
    end
  end
  
  describe "#default_file_labels" do
    it "sets default values" do
      all_suffixes = ['ff','q1','rr','q2','bb','q3','ll','q4','tt','uu','gg','d1','d2','fx','bx','lx','rx','tx','ux','pc1','pc2','other1','other2'] \
                        .map do |s| "file_#{s}.jpg" end
      expect(tools.default_file_labels(all_suffixes)).to eql(["front","quarter 1","right","quarter 2","back","quarter 3","left","quarter 4","top","underside","group","detail 1","detail 2","front inscription","back inscription","left inscription","right inscription","top inscription","underside inscription","post conservation image 1","post conservation image 2","",""])
      expect(tools.default_file_labels(['1_ll.jpg','2_d1.jpg'])).to eql(["left","detail 1"])
      expect(tools.default_file_labels([])).to eql([])
    end
  end

end