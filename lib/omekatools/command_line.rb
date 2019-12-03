require 'omekatools'

module Omekatools
  class CommandLine < Thor
    no_commands{
      def get_sites
        sites = CONFIG.sites.map{ |s| Omekatools::Site.new(s) }
        
        if options[:site].empty?
          # not specifying site will return all sites specified in config
          return sites
        else
          # return only the sites specified
          slist = options[:site].split(',')
          sitenames = []
          sites.each{ |s| sitenames << s.name }
          slist.each{ |s|
            if sitenames.include?(s)
              next
            else
              puts "There is no site named #{s} in your config"
              puts "Run `exe/ot -c` to see list of site names. Exiting..."
              exit
            end
          }
          return sites.select{ |s| slist.include?(s.name) }
        end
      end #def get_sites
    }
    
    map %w[--version -v] => :__version
    desc '--version, -v', 'print the version'
    def __version
      puts "Omeka Data Tools version #{Omekatools::VERSION}, installed #{File.mtime(__FILE__)}"
    end

    map %w[--config -c] => :__config
    desc '--config, -c', 'print out your config settings, including list of site names'
    def __config
      puts "\nYour project working directory:"
      puts Omekatools::WRK_DIR
      puts "\nYour Omeka sites:"
      Omekatools::CONFIG.sites.each { |s|
        site = Omekatools::Site.new(s)
        puts site.name
      }
    end
    
    desc 'get_coll_info', 'get collection info per site, build coll dirs, save metadata'
    long_desc <<-LONGDESC
Collection information is gathered via the ListSets OAI verb. A site may have one, many, or no collections.

If a site has no collections, a single collection is created with the same name as the site. This preserves the site>collection hierarchy for the rest of the processing. The collid assigned to this mock collection will be 0.

For each collection, a directory is created in the site directory. The collection directory name is `coll_{collid}`.

The collid value is the SetSpec number in OAI, and the `:id` value used in the REST API.

For each collection, the Dublin Core description is saved to `coll_dir/_{collid}_DC.xml`. If there is no Dublin Core description for the collection (and the collection in not a mock collection), a warning is written to the log.

_collections.json is written in each site directory to persist collection info.

If _collections.json exists in a site directory, calling `get_coll_info` without `--force=true` will display collection info from the persisted JSON.

If _collections.json does not exist for a site, an OAI request will generate it. 
    LONGDESC
    option :site, :desc => 'comma-separated list of site names to include in processing', :default => ''
    option :force, :desc => 'boolean (true, false) - whether to force refresh of data', :default => false
    def get_coll_info
      sites = get_sites
      sites.each { |site| site.process_colls(options[:force]) }
    end

    desc 'get_ids', 'produce list of identifiers for each site.'
    long_desc <<-LONGDESC
Saves a text file (tab-delimited) of all identifiers in a site. This needs to happen at the site level because, even if collections/specs are set up and supported, it is not required that every item be associated with a collection. We need to pull all ids at the site level (without specifying spec/collection) to ensure we get all items. 

Writes `identifier\tspec/collection\tstatus` to a text file called `site_dir/_ids.txt`
    LONGDESC
    option :site, :desc => 'comma-separated list of site names to include in processing', :default => ''
    option :force, :desc => 'boolean (true, false) - whether to force refresh of data', :default => false
    def get_ids
      sites = get_sites
      sites.each { |site| site.get_identifiers(options[:force]) }
    end

    desc 'get_recs', 'download records for each repo.'
    long_desc <<-LONGDESC
Downloads the Omeka-XML record for each item listed in `site_dir/_ids.txt`.

Records are saved in `site_dir/_oxrecords`.

The file name for each record is its id (sans oai prefix and uri fragment used in formal OAI ID), with file suffix `.xml`
    LONGDESC
    option :site, :desc => 'comma-separated list of site names to include in processing', :default => ''
    option :force, :desc => 'boolean (true, false) - whether to force refresh of data', :default => false
    def get_recs
      sites = get_sites
      sites.each { |site| site.get_records(options[:force]) }
    end

    desc 'make_mig_recs', 'converts omeka-xml records into JSON DC migration records'
    long_desc <<-LONGDESC
`exe/ot make_mig_recs` turns harvested omeka-xml records for each collection into Dublin Core records formatted as JSON.

The JSON format used is patterned on the metadata format output by CONTENTdm, but the fields are DC fields. This allows one tool to handle mappings, cleanup, reporting, etc. on metadata from either tool.

"Migration records" mean migration-specific fields are added to facilitate further processing.

The fields added are:

    - migobjlevel (top or child)

    - migobjcategory (compound (multiple items on record) or simple (one item on record))

    If the object is a compound record, the following fields are also added:

    - migcompobjtype (i.e. Compound (Omeka does not support different compound object types like CDM does))

    - migchildptrs (ordered array of pointers for child objects to be used for fetching the child records)

    - migchilddata (hash of child data for later merging into child records)

    - migparentptr (pointer of parent object)

    - migtitle (pagetitle value from parent object dmGetCompoundObjectInfo call, which is often better data than what is in the title field of the child object record) 

    - migfile (pagefile value from the parent object dmGetCompoundObjectInfo call, in case it is missing from child record

    - migsource (source system: Omeka)
    LONGDESC
    option :site, :desc => 'comma-separated list of site names to include in processing', :default => ''
    option :force, :desc => 'boolean (true, false) - whether to force refresh of data', :default => false
    def make_mig_recs
      sites = get_sites
      sites.each { |site| site.make_mig_recs }
    end

    desc 'get_field_data', 'converts omeka-xml records into JSON DC migration records'
    long_desc <<-LONGDESC
`exe/ot get_field_data` produces a csv file of the descriptive metadata fields used in item records for each site.

This file is written to: `wrk_dir/_fields.csv` and lists the Omeka site, followed by the metadata field.

The data in this file is appropriate for incorporating into metadata mapping documents.
    LONGDESC
    option :site, :desc => 'comma-separated list of site names to include in processing', :default => ''
    def get_field_data
      sites = get_sites
      f = CSV.open("#{Omekatools::WRK_DIR}/_fields.csv", 'wb')
      sites.each { |site| Omekatools::SiteFieldReporter.new(f, site) }
      f.close
    end
    
    desc 'chk_recs', 'testing'
    def chk_recs
      recs = []
      Omekatools::CONFIG.repos.each { |repo|
        rec_dir = Dir.new(repo.rec_dir)
        rec_dir.children.each{ |rf| recs << Omekatools::OxRecord.new(repo, "#{repo.rec_dir}/#{rf}") }
      }
      recs.each{ |r| puts "#{r.obj_type} - #{r.file_ct} files" }
    end

    desc 'sum_recs', 'testing'
    def sum_recs
      recs = []
      Omekatools::CONFIG.repos.each { |repo|
        rec_dir = Dir.new(repo.rec_dir)
        rec_dir.children.each{ |rf| recs << Omekatools::OxRecord.new(repo, "#{repo.rec_dir}/#{rf}") }
      }
      recs.each{ |r| puts "#{r.repo.name}\t#{r.id}\t#{r.obj_type}\t#{r.file_ct}" }
    end
  end
end
