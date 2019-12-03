require 'omekatools'

module Omekatools
  class Site
    attr_reader :name # name of site, derived from site uri
    attr_reader :baseuri # base uri for site, specified in config
    attr_reader :oaiuri # base uri for OAI-PMH repo
    attr_reader :apiuri # base uri for Omeka REST API
    attr_reader :colls # array of collections in the site, as collection objects
    attr_reader :colldata # location of json file persisting collection info
    attr_reader :site_dir # directory containing site data
    attr_reader :oxrecdir # path to directory for Omeka XML records for individual objects
    attr_reader :migrecdir # path to directory for object records modified with migration-specific data
    attr_reader :cleanrecdir # path to directory for transformed/cleaned migration records
    attr_reader :id_file # path to text file of site ids
    attr_reader :migrecs #array of migration record filenames
    
    def initialize(siteuri)
      @name = siteuri.sub(/^https?:\/\//,'').sub(/\..*$/,'')
      @baseuri = siteuri
      @oaiuri = "#{@baseuri}#{Omekatools::CONFIG.oaisuffix}"
      @apiuri = "#{@baseuri}#{Omekatools::CONFIG.apisuffix}"
      @colls = []
      wd = Omekatools::WRK_DIR
      @site_dir = "#{wd}/#{@name}"
      @colldata = "#{@site_dir}/_collections.json"
      @oxrecdir = "#{@site_dir}/_oxrecords"
      @migrecdir = "#{@site_dir}/_migrecords"
      @cleanrecdir = "#{@site_dir}/_cleanrecords"
      @id_file = "#{@site_dir}/_ids.txt"
      make_dirs
    end

    def make_dirs
      [@site_dir, @oxrecdir, @migrecdir, @cleanrecdir].each { |d|
        Dir::mkdir(d) unless Dir::exist?(d)
      }
    end

    def process_colls(force)
      if force == true || !File.exists?(@colldata)
        File.delete(@colldata) if force == true && File.exists?(@colldata)
        get_colls_from_oai
      else
        read_colls
      end
      
      @colls.each { |c|
        puts "Site: #{@name} has Colls: #{c.name} (collID=#{c.collid})"
      }
    end

    def get_colls_from_oai
      client = OAI::Client.new(@oaiuri)
      begin
        colllist = client.list_sets
      rescue OAI::Exception
        colllist = []
      end
      if colllist.count == 0
        @colls << Omekatools::Collection.new(@name, 0, nil, self)
      else
        colllist.each { |coll| @colls << Omekatools::Collection.new(coll.name, coll.spec, coll.description, self) }
      end
      write_colls
    end

    def write_colls
      colls_to_write = []
      @colls.each{ |c| colls_to_write << c.to_h }
      File.open(@colldata, 'w'){ |f|
        f.write(colls_to_write.to_json)
      }
    end

    def read_colls
      colls = JSON.parse(File.read(@colldata))
      colls.each{ |c| @colls << Omekatools::Collection.new(c['name'], c['collid'], c['desc'], self) }
    end

    def get_identifiers(force)
      if File::exist?(@id_file) && force == false
        Omekatools::LOG.info("Did not overwrite existing id file at #{@id_file}")
      else
        client = OAI::Client.new(@oaiuri)
        # The following produces a temp full list you can only iterate over once without
        #  using resumption tokens
        ids = client.list_identifiers.full
        # So we go old school to produce a count of ids
        id_ct = 0
        File.open(@id_file, 'w') { |f|
          ids.each { |id|
            # The set_spec attribute is returned as an array of REXML elements
            spec = ''
            if id.set_spec.count > 0
              sets = []
              id.set_spec.each{ |s| sets << s.text }
              spec = sets.join(';;;')
            end
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

    def get_records(force)
      if rec_ct_equals_id_ct == true && force == false
        Omekatools::LOG.info("There are #{get_id_ct} ids and records for repo #{@name}. Skipping downloading records you already have.")
      elsif get_id_ct == 0
        Omekatools::LOG.warn("There are no ids for repo #{@name}. Try running with 'get_ids' command first.")
        exit
      elsif get_rec_ct > 0 && force == false
        puts "You need to write code to compare number of IDs vs. number of existing records in order to get only the records you need."
        exit
      else
        get_all_records
      end
    end

    def make_mig_recs
      Dir.children(@oxrecdir).each{ |oxrec|
        Omekatools::OxRecord.new(self, "#{@oxrecdir}/#{oxrec}").make_mig_rec
      }
    end

    def set_migrecs
      @migrecs = Dir.new(@migrecdir).children
      if @migrecs.length == 0
        Omekatools::LOG.error("No records in #{@migrecdir}.")
        return
      else
        Omekatools::LOG.info("Identified #{@migrecs.length} records for #{@alias}...")
      end
    end

    private

    def get_all_records
      ids = []
      File.open(@id_file, 'r').each { |ln| ids << ln.split("\t")[0] }

      puts "Getting #{ids.count} records for #{@name}..."
      progressbar = ProgressBar.create(:format => '%a |%b>>%i| %p%% %t', :autofinish => false, :total => ids.count)

      ids.each { |id|
        uri = URI("#{@oaiuri}?verb=GetRecord&identifier=#{id}&metadataPrefix=omeka-xml")
        result = Net::HTTP.get_response(uri)

        case result
        when Net::HTTPSuccess then
          idpiece = id.sub(/^.*omeka\.net:/, '')
          outfile = "#{@oxrecdir}/#{idpiece}.xml"
          File.open(outfile, 'w'){ |f|
            f.write(result.body)
          }
        else
          Omekatools::LOG.error("Problem getting record: #{id} -- #{result.code} : #{result.message}")
        end

        progressbar.increment
      }
      progressbar.finish
    end
    
    def get_id_ct
      if File::exist?(@id_file)
        return `wc -l #{@id_file}`.strip.split(' ')[0].to_i
      else
        puts "No id file for site: #{@name}. Run `exe/ot get_ids`"
        exit
      end
    end

    def get_rec_ct
      Dir.children(@oxrecdir).count
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
    
  end #Site class
end #Omekatools
