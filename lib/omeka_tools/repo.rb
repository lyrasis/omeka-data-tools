require 'omeka_tools'

module OmekaTools
  class Repo
    attr_reader :name
    attr_reader :uri
    attr_reader :sets
    attr_reader :wrk_dir
    attr_reader :repo_dir
    attr_reader :rec_dir
    attr_reader :obj_dir
    attr_reader :id_file

    def initialize(repo, wrk_dir)
      @name = repo[:name]
      @uri = repo[:uri]
      @sets = []
      @wrk_dir = wrk_dir
      @repo_dir = "#{wrk_dir}/#{@name}"
      @rec_dir = "#{repo_dir}/records"
      @obj_dir = "#{repo_dir}/objects"
      @id_file = "#{@repo_dir}/id_list.txt"
      make_dirs
    end

    def make_dirs
      [@repo_dir, @rec_dir, @obj_dir].each { |d|
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
      setlist.each { |set| @sets << OmekaTools::Set.new(set, self) } if setlist.count > 0
    end

    def get_identifiers
      if File::exist?(@id_file)
        OmekaTools::LOG.info("Did not overwrite existing id file at #{@id_file}")
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
            OmekaTools::LOG.info("Wrote #{id_ct} ids to #{@id_file}")
          else
            OmekaTools::LOG.warn("Repo #{@name} has no records. Blank file written at #{@id_file}")
          end
      end
    end # get_identifiers

    def get_records
      if rec_ct_equals_id_ct == true
        OmekaTools::LOG.info("There are #{get_id_ct} ids and records for repo #{@name}. Skipping downloading records you already have.")
      elsif get_id_ct == 0
        OmekaTools::LOG.warn("There are no ids for repo #{@name}. Try running with 'get_ids' command first.")
      elsif get_rec_ct > 0
        puts "You need to write code to compare number of IDs vs. number of existing records in order to get only the records you need."
      else
        get_all_records
      end
    end

    private

    def get_all_records
      ids = []
      File.open(@id_file, 'r').each { |ln| ids << ln.split("\t")[0] }

      if ids.count > 100
        pbtotal = 100
        pbscaled = true
      else
        pbtotal = ids.count
        pbscaled = false
      end
      
      puts "Getting #{ids.count} records..."
      progressbar = ProgressBar.create(:format => '%a |%b>>%i| %p%% %t', :autofinish => false, :total => pbtotal)
      puts ""
      ct = 0
      factor = 100.to_f / ids.count.to_f if pbscaled
      fct = 0 if pbscaled

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
          OmekaTools::LOG.error("Problem getting record: #{id} -- #{result.code} : #{result.message}")
        end

        ct += 1
        if pbscaled
          new_fct = (ct * factor).floor
          unless new_fct == fct
            progressbar.increment
            fct = new_fct
          end
        else
          progressbar.increment
        end
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
        OmekaTools::LOG.info("There are #{id_ct} ids and #{rec_ct} records for repo #{@name}.")
        return false
      end
    end
    
  end #Repo class
end #OmekaTools
