def Hilda.queue
  @queue ||= Hilda::Resque::Queue.new('hilda')
end

def Hilda.config
  @config ||= YAML.load_file(Rails.root.join('config','hilda.yml'))[Rails.env]
end

Time::DATE_FORMATS[:default] = '%Y-%m-%d %H:%M:%S'
