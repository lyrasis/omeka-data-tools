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
    attr_reader :objdir
    attr_reader :id_file # path to text file of site ids
    attr_reader :oxrecs #array of omeka-xml record filenames
    attr_reader :migrecs #array of migration record filenames
    attr_reader :cleanrecs #array of clean record filenames
    attr_reader :objs_by_category
    attr_reader :simpleobjs
    attr_reader :compoundobjs
    attr_reader :compoundchildren
    attr_reader :externalmedia
    
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
      @objdir = "#{@site_dir}/_objects"
      @cleanrecdir = "#{@site_dir}/_cleanrecords"
      @id_file = "#{@site_dir}/_ids.txt"
      make_dirs
    end

    def make_dirs
      [@site_dir, @oxrecdir, @migrecdir, @cleanrecdir, @objdir].each { |d|
        Dir::mkdir(d) unless Dir::exist?(d)
      }
    end

    def process_colls(force)
      if force == 'true' || !File.exists?(@colldata)
        File.delete(@colldata) if force == 'true' && File.exists?(@colldata)
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
      if File::exist?(@id_file) && force == 'false'
        Omekatools::LOG.info("Did not overwrite existing id file at #{@id_file}")
      else
        File.delete(@id_file) if File::exist?(@id_file)
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
      if rec_ct_equals_id_ct == true && force == 'false'
        Omekatools::LOG.info("There are #{get_id_ct} ids and records for repo #{@name}. Skipping downloading records you already have.")
      elsif get_id_ct == 0
        Omekatools::LOG.warn("There are no ids for repo #{@name}. Try running with 'get_ids' command first.")
        exit
      elsif get_rec_ct > 0 && force == 'false'
        get_select_records(get_needed_ids)
      else
        get_all_records
      end
    end

    def make_mig_recs(force)
      set_oxrecs
      if force == 'true'
        to_create = @oxrecs
      else
        set_migrecs
        migrec_ids = @migrecs.map{ |filename| filename.sub('.json', '.xml') }
        oxrec_ids = @oxrecs
        to_create = oxrec_ids - migrec_ids
      end

      if to_create.length > 0
      progressbar = ProgressBar.create(:title => "Creating migrecords for #{@name}",
                                       :format => '%t : %a |%b>>%i| %p%%',
                                       :total => to_create.length)
      to_create.each{ |oxrec|
        Omekatools::OxRecord.new(self, "#{@oxrecdir}/#{oxrec}").make_mig_rec
        progressbar.increment
      }
      progressbar.finish
      end
    end

    def add_setspec_to_migrecs
      create_objs_by_category
      doobjs = @simpleobjs + @compoundobjs + @externalmedia
      doobjs.each{ |id|
        Omekatools::LOG.debug("ADD_SETSPEC: Checking #{@name}/#{id} for set spec")
        oxrec = Nokogiri::XML(File.open("#{@oxrecdir}/#{id}.xml")).remove_namespaces!
        setspec = oxrec.xpath("/OAI-PMH/GetRecord/record/header/setSpec").text
        Omekatools::LOG.debug("ADD_SETSPEC: #{@name}/#{id}: setspec = #{setspec}")
        unless setspec.empty?
          update_migrec_with_set(id, setspec)
        end
      }
      
      @compoundchildren.each{ |id|
          Omekatools::LOG.debug("ADD_SETSPEC: Checking #{@name}/#{id} for set spec")
          update_child_migrec_with_set(id)
        }
    end

    def update_migrec_with_set(recid, setspec)
      recpath = "#{@migrecdir}/#{recid}.json"
      migrec = JSON.parse(File.read(recpath))
      migrec['migcollectionset'] = setspec
      File.open(recpath, 'w'){ |f| f.write(migrec.to_json) }
      Omekatools::LOG.debug("ADD_SETSPEC: Wrote migcollectionset field to #{@name}/#{recid}")
    end

    def update_child_migrec_with_set(recid)
      childrecpath = "#{@migrecdir}/#{recid}.json"
      childmigrec = JSON.parse(File.read(childrecpath))
      parentrecpath = "#{@migrecdir}/#{childmigrec['migparentptr']}.json"
      parentmigrec = JSON.parse(File.read(parentrecpath))
      setspec = parentmigrec['migcollectionset']
      update_migrec_with_set(recid, setspec) if setspec
    end

    def get_metadata_only_links
      create_objs_by_category
      unless @objs_by_category['metadata only'].empty?
        @objs_by_category['metadata only'].each{ |recid|
          oxrec = Nokogiri::XML(File.open("#{@oxrecdir}/#{recid}.xml")).remove_namespaces!
          type = oxrec.xpath("/OAI-PMH/GetRecord/record/metadata/item/itemType/name").text
          if type && type == 'Hyperlink'
            urlcode = oxrec.xpath("/OAI-PMH/GetRecord/record/metadata/item/itemType/elementContainer/element/elementTextContainer/elementText/text").text
            url = urlcode.match(/href="(http.*?)"/)[1] if urlcode
            if url
          recpath = "#{@migrecdir}/#{recid}.json"
          migrec = JSON.parse(File.read(recpath))
          migrec['externalmedialink'] = url
          File.open(recpath, 'w'){ |f| f.write(migrec.to_json) }
          Omekatools::LOG.debug("METADATA_ONLY_LINKS: Wrote externalmedialink field to #{@name}/#{recid}")
            end
          end
        }
      end
    end
    
    def set_cleanrecs
      @cleanrecs = Dir.new(@cleanrecdir).children
      if @cleanrecs.length == 0
        Omekatools::LOG.error("No records in #{@cleanrecdir}.")
        return
      else
        Omekatools::LOG.info("Identified #{@cleanrecs.length} records for #{@name}...")
      end
    end

    def set_migrecs
      @migrecs = Dir.new(@migrecdir).children
      if @migrecs.length == 0
        Omekatools::LOG.error("No records in #{@migrecdir}.")
        return
      else
        Omekatools::LOG.info("Identified #{@migrecs.length} records for #{@name}...")
      end
    end

    def set_oxrecs
      @oxrecs = Dir.new(@oxrecdir).children
      if @oxrecs.length == 0
        Omekatools::LOG.error("No records in #{@oxrecdir}.")
        return
      else
        Omekatools::LOG.debug("Identified #{@oxrecs.length} records for #{@name}...")
      end
    end

    def harvest_objects
      create_objs_by_category
      puts "Harvesting #{@simpleobjs.count} simple objects for #{@name}..."
      progressbar = ProgressBar.create(:format => '%a |%b>>%i| %p%% %t', :autofinish => false, :total => @simpleobjs.count)
      @simpleobjs.each{ |pointer|
        Omekatools::ObjectHarvester.new(self, pointer)
        progressbar.increment
      }
      progressbar.finish

      puts "Harvesting #{@compoundchildren.count} child objects for #{@name}..."
      progressbar = ProgressBar.create(:format => '%a |%b>>%i| %p%% %t', :autofinish => false, :total => @compoundchildren.count)
      @compoundchildren.each{ |pointer|
        Omekatools::ObjectHarvester.new(self, pointer)
        progressbar.increment
      }
      progressbar.finish
    end

    def print_object_hash
      create_objs_by_category
      puts "\n\n#{@name}"
      pp(@objs_by_category)
    end

    def report_object_stats
      create_objs_by_category
      puts "\n\n#{@name}"
      puts "SIMPLE OBJECTS"
      @objs_by_category.each{ |k, v|
        unless k == 'compound' || k == 'children'
          puts "  #{k}: #{v.length}" unless v.empty?
        end
      }
      all_cpd = []
      @objs_by_category['compound'].each{ |k, v|
        all_cpd << v
      }
      all_cpd.flatten!
      
      puts "COMPOUND OBJECTS" unless all_cpd.empty?
      
      @objs_by_category['compound'].each{ |k, v|
        unless v.empty?
          puts "  #{k}: #{v.length}"
          puts "    CHILD OBJECTS"
          @objs_by_category['children'][k].each{ |ft, ptrs|
            puts "      #{ft}: #{ptrs.length}"
          }
        end
      }

    end

    private

    def create_objs_by_category
      @objs_by_category = {
        'external media' => [],
        'metadata only' => [],
        'compound' => {'compound' => []},
        'children' => {'compound' => {}}
      }
      Dir.new(@migrecdir).children.each{ |recname|
        rec = JSON.parse(File.read("#{@migrecdir}/#{recname}"))
        pointer = rec['migptr']
        filetype = rec['migfiletype'].downcase if rec['migfiletype']

        case rec['migobjlevel']
        when 'top'
          case rec['migobjcategory']
          when 'simple'
            if @objs_by_category.has_key?(filetype)
              @objs_by_category[filetype] << pointer
            else
              @objs_by_category[filetype] = [pointer]
            end
          when 'metadata'
            @objs_by_category['metadata only'] << pointer
          when 'external media'
            @objs_by_category['external media'] << pointer
          when 'compound'
            @objs_by_category['compound']['compound'] << pointer            
          end
        when 'child'
          if @objs_by_category['children']['compound'].has_key?(filetype)
            @objs_by_category['children']['compound'][filetype] << pointer
          else
            @objs_by_category['children']['compound'][filetype] = [pointer]
          end
        end
      }
      set_simpleobjs
      set_compoundobjs
      set_compoundchildren
      set_externalmedia
    end

    def set_externalmedia
      @externalmedia = @objs_by_category['external media']
    end
    
    def set_compoundobjs
      @compoundobjs = @objs_by_category['compound']['compound']
    end

    def set_compoundchildren
      pointers = []
      @objs_by_category['children']['compound'].each{ |filetype, ptrs| pointers << ptrs }
      @compoundchildren = pointers.flatten
    end

    def set_simpleobjs
      pointers = []
      exclude = ['compound', 'children', 'external media']
      
      @objs_by_category.each{ |category, data|
        pointers << data unless exclude.include?(category)
      }
      @simpleobjs = pointers.flatten
    end

    def get_all_records
      ids = []
      File.open(@id_file, 'r').each { |ln| ids << ln.split("\t")[0] }

      puts "Getting #{ids.count} records for #{@name}..."
      progressbar = ProgressBar.create(:format => '%a |%b>>%i| %p%% %t', :autofinish => false, :total => ids.count)

      ids.each { |id|
        Omekatools::OxrecordHarvester.new(@oaiuri, id, @oxrecdir)
        progressbar.increment
      }
      progressbar.finish
    end

    def get_select_records(ids)
      puts "Getting #{ids.count} records for #{@name}..."
      progressbar = ProgressBar.create(:format => '%a |%b>>%i| %p%% %t', :autofinish => false, :total => ids.count)

      ids.each { |id|
        Omekatools::OxrecordHarvester.new(@oaiuri, id, @oxrecdir)
        progressbar.increment
      }
      progressbar.finish
    end

    def get_ids
      if File::exist?(@id_file)
        ids = []
        File.open(@id_file, 'r').each { |ln| ids << ln.split("\t")[0] }
        return ids
      else
        puts "No id file for site: #{@name}. Run `exe/ot get_ids`"
        exit
      end
    end

    def get_id_ct
      if File::exist?(@id_file)
        return get_ids.count
      else
        puts "No id file for site: #{@name}. Run `exe/ot get_ids`"
        exit
      end
    end

    def get_needed_ids
      ids = get_ids
      id_prefix = ids.first.sub(/:\d+$/, ':')
      set_oxrecs
      recids = @oxrecs.map{ |filename| id_prefix + filename.delete('.xml') }
      puts @name
      return ids - recids
    end

    def get_rec_ct
      set_oxrecs
      @oxrecs.count
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
