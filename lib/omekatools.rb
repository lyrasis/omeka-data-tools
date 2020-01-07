# standard library
require 'csv'
require 'json'
require 'logger'
require 'net/http'
require 'pp'
require 'yaml'

# external gems
require 'oai'
require 'nokogiri'
require 'progressbar'
require 'thor'

module Omekatools
  autoload :VERSION, 'omekatools/version'
  autoload :CONFIG, 'omekatools/config_reader'
  autoload :LOG, 'omekatools/log'
  # silly way to make Omekatools::WRK_DIR act like a global variable
  autoload :WRK_DIR, 'omekatools/wrk_dir'

  autoload :Collection, 'omekatools/collection'
  
  autoload :CommandLine, 'omekatools/command_line'

  autoload :ConfigReader, 'omekatools/config_reader'

  autoload :FileInfoGetter, 'omekatools/file_info_getter'
  autoload :ChildFileInfoGetter, 'omekatools/file_info_getter'
  autoload :SimpleFileInfoGetter, 'omekatools/file_info_getter'
  
  autoload :MigRecBuilder, 'omekatools/mig_rec_builder'
  autoload :ChildMigRecBuilder, 'omekatools/mig_rec_builder'
  
  autoload :MigRecord, 'omekatools/record'
  autoload :OxRecord, 'omekatools/record'
  autoload :Record, 'omekatools/record'

  autoload :Repo, 'omekatools/repo'

  autoload :Site, 'omekatools/site'
  
end
