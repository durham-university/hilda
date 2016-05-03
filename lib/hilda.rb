require 'sass-rails'
require 'jquery-rails'
require 'dropzonejs-rails'
require 'simple_form'
require 'active-fedora'
require 'mimemagic'
require 'mimemagic/overlay'
require 'durham_rails'
require "hilda/engine"

module Hilda
  def self.queue
    @queue ||= Hilda::Resque::Queue.new('hilda')
  end

  def self.config
    @config ||= begin
      path = Rails.root.join('config','hilda.yml')
      if File.exists?(path)
        YAML.load(ERB.new(File.read(path)).tap do |erb| erb.filename = path.to_s end .result)[Rails.env]
      else
        {}
      end
    end
  end
end
