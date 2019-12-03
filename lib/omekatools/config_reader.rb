require 'omekatools'

module Omekatools
  class ConfigReader
    attr_reader :wrk_dir
    attr_reader :sites
    attr_reader :oaisuffix
    attr_reader :apisuffix
    attr_reader :logfile

    def initialize
      config = YAML.load_file('config/config.yaml')
      @wrk_dir = config['wrk_dir']
      @logfile = config['logfile']
      @oaisuffix = config['oai_repo_suffix']
      @apisuffix = config['api_suffix']
      @sites = config['sites']
    end
  end

  CONFIG = Omekatools::ConfigReader.new
end
