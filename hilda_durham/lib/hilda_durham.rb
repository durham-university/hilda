require 'sass-rails'
require 'jquery-rails'
require 'simple_form'
require "hilda_durham/engine"

module HildaDurham
  extend ActiveSupport::Autoload

  autoload :MuseumTools

  def self.config
    @config ||= {} # YAML.load_file(Rails.root.join('config','hilda_durham.yml'))[Rails.env]
  end
end
