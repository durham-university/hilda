require 'sass-rails'
require 'jquery-rails'
require 'dropzonejs-rails'
require 'simple_form'
require 'active-fedora'
require 'mimemagic'
require 'mimemagic/overlay'
require "hilda/engine"

module Hilda
  def self.queue
    @queue ||= Hilda::Resque::Queue.new('hilda')
  end

  def self.config
    @config ||= YAML.load_file(Rails.root.join('config','hilda.yml'))[Rails.env]
  end
end
