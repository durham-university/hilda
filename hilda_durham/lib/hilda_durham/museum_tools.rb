module HildaDurham
  class MuseumTools
    def self.default_file_labels(file_names)
      suffix_re = /^.*[_ -]([^\.]+)\.[^\.]+$/
      labels = {
        'ff' => 'front',
        'bb' => 'back',
        'll' => 'left',
        'rr' => 'right',
        'tt' => 'top',
        'uu' => 'underside',
        /^q([1-4])$/ => 'quarter \1',
        'gg' => 'group',
        /^d([0-9]+)$/ => 'detail \1',
        'fx' => 'front inscription',
        'bx' => 'back inscription',
        'lx' => 'left inscription',
        'rx' => 'right inscription',
        'tx' => 'top inscription',
        'ux' => 'underside inscription',
        /^pc([0-9]+)$/ => 'post conservation image \1'
      }
      file_names.map do |file_name|
        m = suffix_re.match(file_name)
        if m.present?
          suffix = m[1].downcase
          labels.to_a.map do |matcher,replacement|
            case matcher
            when String
              (matcher == suffix) && replacement
            when Regexp
              (matcher.match(suffix).present?) && suffix.gsub(matcher, replacement)
            end
          end .find(&:present?) || ''
        else
          ''
        end
      end
    end
    
    def self.sort(files)
      ret = {}
      ['ff','q1','ll','q2','bb','q3','rr','q4','tt','uu','q[0-9]+','gg','d[0-9]+',
             'fx','bx','lx','rx','tx','ux','pc[0-9]+'].each do |suffix|
        ret.merge!(self.find_files(files,suffix))
      end
      ret.merge!(self.remaining_files(files, ret))
      ret
    end
    
    def self.find_files(files,suffix)
      re = /^.*[_ -](#{suffix})\.[^\.]+$/
      files.each_with_object([]) do |(key,file),selected|
        m = re.match(file[:original_filename])
        next unless m
        selected << [key,file,m[1]]
      end .sort do |a,b|
        a[2] <=> b[2]
      end .map do |s|
        [s[0],s[1]]
      end .to_h
    end
    
    def self.remaining_files(original_files, picked_files)
      original_files.each_with_object({}) do |(key,file),ret|
        ret[key] = file unless picked_files.key?(key)
      end
    end
  end
end