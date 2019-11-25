require 'omeka_tools'

module OmekaTools
  class ConfigReader
    attr_reader :wrk_dir
    attr_reader :repos
    attr_reader :logfile

    def initialize
      config = YAML.load_file('lib/config.yaml')
      @wrk_dir = config['wrk_dir']
      @logfile = config['logfile']
      @repos = []
      config['oai_repos'].each do |repo|
        name = repo.sub(/^https?:\/\//,'').sub(/\..*$/,'')
        @repos << OmekaTools::Repo.new({ :name => name, :uri => repo }, @wrk_dir)
      end
    end
  end

  CONFIG = OmekaTools::ConfigReader.new
  WDIR = CONFIG.wrk_dir

end
