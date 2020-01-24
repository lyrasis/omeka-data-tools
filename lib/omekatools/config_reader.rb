require 'omekatools'

module Omekatools
  class ConfigReader
    attr_reader :wrk_dir
    attr_reader :sites
    attr_reader :oaisuffix
    attr_reader :apisuffix
    attr_reader :logfile

    def initialize(configpath = 'config/config.yaml')
      @path = configpath.is_a?(String) ? configpath : configpath[:config]
      config = YAML.load_file(File.expand_path(@path))
      @wrk_dir = config['wrk_dir']
      @logfile = config['logfile']
      @oaisuffix = config['oai_repo_suffix']
      @apisuffix = config['api_suffix']
      @sites = config['sites']
    end
  end
end
