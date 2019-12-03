require 'omekatools'

module Omekatools
  class Repo
    attr_reader :name
    attr_reader :uri
    attr_reader :sets
    attr_reader :wrk_dir
    attr_reader :repo_dir
    attr_reader :rec_dir
    attr_reader :mig_rec_dir
    attr_reader :obj_dir
    attr_reader :id_file

    def initialize(repo, wrk_dir)
      @name = repo[:name]
      @uri = repo[:uri]
      @sets = []
      @wrk_dir = wrk_dir
      @repo_dir = "#{wrk_dir}/#{@name}"
      @rec_dir = "#{repo_dir}/records"
      @mig_rec_dir = "#{repo_dir}/mig_records"
      @obj_dir = "#{repo_dir}/objects"
      @id_file = "#{@repo_dir}/id_list.txt"
      make_dirs
    end

    def make_dirs
      [@repo_dir, @rec_dir, @mig_rec_dir, @obj_dir].each { |d|
        Dir::mkdir(d) unless Dir::exist?(d)
      }
    end

    def process_sets
      get_sets
      @sets.each { |s| puts "Repo: #{@name} has Set: #{s.name}" } if @sets.count > 0
    end

    def get_sets
      client = OAI::Client.new(@uri)
      begin
        setlist = client.list_sets
      rescue OAI::Exception
        setlist = []
      end
      setlist.each { |set| @sets << Omekatools::Set.new(set, self) } if setlist.count > 0
    end

    def get_identifiers
      if File::exist?(@id_file)
        Omekatools::LOG.info("Did not overwrite existing id file at #{@id_file}")
      else
        client = OAI::Client.new(@uri)
        # The following produces a temp full list you can only iterate over once without
        #  using resumption tokens
        ids = client.list_identifiers.full
        # So we go old school to produce a count of ids
        id_ct = 0
          File.open(@id_file, 'w') { |f|
            ids.each { |id|
              # The set_spec attribute is returned as an array of REXML elements
              spec = ''
              spec = id.set_spec[0].text if id.set_spec.count > 0
              f.write("#{id.identifier}\t#{spec}\t#{id.status}\n")
              id_ct += 1
            }
          }
          if id_ct > 0
            Omekatools::LOG.info("Wrote #{id_ct} ids to #{@id_file}")
          else
            Omekatools::LOG.warn("Repo #{@name} has no records. Blank file written at #{@id_file}")
          end
      end
    end # get_identifiers

    def get_records
      if rec_ct_equals_id_ct == true
        Omekatools::LOG.info("There are #{get_id_ct} ids and records for repo #{@name}. Skipping downloading records you already have.")
      elsif get_id_ct == 0
        Omekatools::LOG.warn("There are no ids for repo #{@name}. Try running with 'get_ids' command first.")
      elsif get_rec_ct > 0
        puts "You need to write code to compare number of IDs vs. number of existing records in order to get only the records you need."
      else
        get_all_records
      end
    end

    def make_mig_recs
      Dir.children(@rec_dir).each{ |oxrec|
        Omekatools::OxRecord.new(self, "#{@rec_dir}/#{oxrec}").make_mig_rec
      }
    end
    
    private

    def get_all_records
      ids = []
      File.open(@id_file, 'r').each { |ln| ids << ln.split("\t")[0] }

      puts "Getting #{ids.count} records..."
      progressbar = ProgressBar.create(:format => '%a |%b>>%i| %p%% %t', :autofinish => false, :total => ids.count)

      ids.each { |id|
        uri = URI("#{@uri}?verb=GetRecord&identifier=#{id}&metadataPrefix=omeka-xml")
        result = Net::HTTP.get_response(uri)

        case result
        when Net::HTTPSuccess then
          idpiece = id.sub(/^.*omeka\.net:/, '')
          outfile = "#{@rec_dir}/#{idpiece}.xml"
          File.open(outfile, 'w'){ |f|
            f.write(result.body)
          }
        else
          Omekatools::LOG.error("Problem getting record: #{id} -- #{result.code} : #{result.message}")
        end

        progressbar.increment
      }
    end
    
    def get_id_ct
      return `wc -l #{@id_file}`.strip.split(' ')[0].to_i
    end

    def get_rec_ct
      Dir.children(@rec_dir).count
    end
    
    def rec_ct_equals_id_ct
      id_ct = get_id_ct
      rec_ct = get_rec_ct
      if id_ct == rec_ct
        return true
      else
        Omekatools::LOG.info("There are #{id_ct} ids and #{rec_ct} records for repo #{@name}.")
        return false
      end
    end
    
  end #Repo class
end #Omekatools
