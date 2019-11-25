# standard library
require 'logger'
require 'net/http'
require 'yaml'

# external gems
require 'oai'
require 'nokogiri'
require 'progressbar'
require 'thor'

module OmekaTools
  autoload :VERSION, 'omeka_tools/version'
  autoload :CONFIG, 'omeka_tools/config_reader'
  autoload :LOG, 'omeka_tools/log'
  autoload :CommandLine, 'omeka_tools/command_line'
  autoload :Repo, 'omeka_tools/repo'
  autoload :Set, 'omeka_tools/set'
  autoload :Record, 'omeka_tools/record'
end
