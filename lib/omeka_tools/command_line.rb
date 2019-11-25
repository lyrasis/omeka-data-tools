require 'omeka_tools'

module OmekaTools
  
  class CommandLine < Thor
    map %w[--version -v] => :__version
    desc '--version, -v', 'print the version'
    def __version
      puts "Omeka OAI Profiler version #{OmekaTools::VERSION}, installed #{File.mtime(__FILE__)}"
    end

    map %w[--config -c] => :__config
    desc '--config, -c', 'print out your config settings'
    def __config
      puts "\nYour project working directory:"
      puts OmekaTools::CONFIG.wrk_dir
      puts "\nYour OAI-PMH repos:"
      OmekaTools::CONFIG.repos.each { |r| puts r.name }
    end
    
    desc 'get_set_info', 'get set info per repo, build dirs, save metadata'
    def get_set_info
      OmekaTools::CONFIG.repos.each { |repo| repo.process_sets }
    end

    desc 'get_ids', 'produce list of identifiers for each repo.'
    def get_ids
      OmekaTools::CONFIG.repos.each { |repo| repo.get_identifiers }
    end

    desc 'get_recs', 'download records for each repo.'
    def get_recs
      OmekaTools::CONFIG.repos.each { |repo| repo.get_records }
    end

    desc 'chk_recs', 'testing'
    def chk_recs
      recs = []
      OmekaTools::CONFIG.repos.each { |repo|
        rec_dir = Dir.new(repo.rec_dir)
        rec_dir.children.each{ |rf| recs << OmekaTools::Record.new(repo, "#{repo.rec_dir}/#{rf}") }
      }
      recs.each{ |r| puts "#{r.obj_type} - #{r.file_ct} files" }
    end

    desc 'sum_recs', 'testing'
    def sum_recs
      recs = []
      OmekaTools::CONFIG.repos.each { |repo|
        rec_dir = Dir.new(repo.rec_dir)
        rec_dir.children.each{ |rf| recs << OmekaTools::Record.new(repo, "#{repo.rec_dir}/#{rf}") }
      }
      recs.each{ |r| puts "#{r.repo.name}\t#{r.obj_type}\t#{r.file_ct}" }
    end
  end
end
