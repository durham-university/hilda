source 'https://rubygems.org'

gemspec

gem 'durham_rails', path: File.expand_path("../../durham_rails", __FILE__)

test_app_gemfile_path = File.expand_path("../test_app/Gemfile", __FILE__)
if File.exists?(test_app_gemfile_path)
  instance_eval (File.read(test_app_gemfile_path).lines.select do |line|
    !(line.index('hilda') || line.index('source') || line.index('durham_rails'))
  end).join("\n")
end
