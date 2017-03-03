namespace :hilda_durham do
  def csv_values(folder, xml_record, ark, fragment)
    xml_record = xml_record.sub_item(fragment) if fragment.present?
    [
      folder,
      xml_record.title || xml_record.id,
      xml_record.author,
      xml_record.date,
      xml_record.scopecontent,
      ark,
      fragment
    ]
  end
  def output_record_csv(folder, xml_record, ark, fragment)
    csv_line = csv_values(folder, xml_record, ark, fragment).to_csv(force_quotes: true)
    puts csv_line    
  end
  
  desc "Fetches metadata from Schmit for letters ingestion"
  task "fetch_records" , [:csv_path] => :environment do |t,args|
    csv_path = args[:csv_path].to_s
    unless csv_path.present? && File.exists?(csv_path)
      puts 'Usage:'
      puts '  bundle exec rake hilda_durham:fetch_records[csv_path]'      
    else
      cached_records = {}
      csv_file = File.open(csv_path,'rb')
      csv_file.each_line do |line|
        line = line.strip
        next if line.blank? || line.start_with?('#')
        folder, ark, fragment = line.parse_csv
        unless ark.present?
          puts "Error parsing input file. File should be CSV with three values per line: letter image folder, record ARK and optional record fragment id."
          return
        end
        xml_record = if cached_records.key?(ark)
          cached_records[ark]
        else
          record = Schmit::API::Catalogue.find(ark)
          unless record
            puts "Couldn't find record #{ark} in Schmit"
            return
          end
          cached_records[ark] = record.xml_record
        end
        output_record_csv(folder, xml_record, ark, fragment)
      end
    end
  end
  
  def set_folder(row)
    split = row[1].split(/,\s*/)
    return unless split.length == 2
    i1 = split[0].to_i
    if split[1].match(/^[0-9].*$/)
      m = split[1].match(/^([0-9]+)(.*)$/)
      i2 = "%03d%s"%([m[1].to_i,m[2]])
    else
      i2 = split[1]
    end
    row[0] = "#{i1}/#{i2}"
  end
  
  desc "Creates letters ingestion CSV based on sub-items of a catalogue"
  task "sub_item_list", [:item_ark] => :environment do |t,args|
    item_ark = args[:item_ark].to_s
    unless item_ark.present?
      puts 'Usage:'
      puts '  bundle exec rake hilda_durham:sub_item_list[item_ark]'      
    else
      record = Schmit::API::Catalogue.find(item_ark)
      unless record
        puts "Couldn't find record #{item_ark} in Schmit"
        return
      end
      xml_record = record.xml_record
      xml = xml_record.xml
      ids = xml.xpath('//*[@level="item"]/did/unitid/@id').map(&:text)
      ids.each do |sub_record_id|
        values = csv_values(sub_record_id, xml_record, item_ark, sub_record_id)
        set_folder(values)
        puts values.to_csv(force_quotes: true)
      end
    end
  end
end