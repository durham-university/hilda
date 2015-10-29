source 'https://rubygems.org'

gemspec

test_app_gemfile_path = File.expand_path("../test_app/Gemfile", __FILE__)
if File.exists?(test_app_gemfile_path)
  instance_eval (File.read(test_app_gemfile_path).lines.select do |line|
    !(line.index('hilda') || line.index('source'))
  end).join("\n")
end
