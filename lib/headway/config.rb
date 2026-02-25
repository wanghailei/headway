# lib/headway/config.rb
require "yaml"

module Headway
  class Config
    attr_reader :data

    def initialize(path = "config/headway.yml")
      @data = YAML.load_file(path)
    end
  end
end
