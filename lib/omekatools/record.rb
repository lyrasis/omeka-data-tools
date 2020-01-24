require 'omekatools'

module Omekatools
  class Record
    attr_reader :site # Omeka site to which record belongs

    def initialize(site, path)
      @site = site
      @path = path
    end
  end #Record class

  class MigRecord < Record
    attr_reader :rec # the record as a JSON-derived hash
    attr_reader :fields # array of fields present in record

    def initialize(site, path)
      super
      @rec = JSON.parse(File.read(@path))
      @fields = @rec.keys
    end

    def write_record
      File.open(@path, 'w'){ |f|
        f.write(@rec.to_json)
      }
    end
    
  end # MigRecord

  #Omeka-XML record 
  class OxRecord < Record
    attr_reader :id # just numeric part of the OAI ID, for use within site/set
    attr_reader :doc # Nokogiri XML document, with namespaces removed
    attr_reader :file_ct # Count of associated files
    attr_reader :obj_type # metadata (no files); simple (1 file); compound (>1 files)
    attr_reader :set_spec #set/collection id number

    def initialize(site, path)
      super(site, path)
      @id = File.basename(path).sub('.xml', '')
      @doc = Nokogiri::XML(File.open(path)).remove_namespaces!
      @file_ct = count_files
      @obj_type = get_obj_type
      @set_spec = @doc.xpath("/OAI-PMH/GetRecord/record/header/setSpec").text
    end

    def make_mig_rec
      Omekatools::MigRecBuilder.new(self)
    end
    
    private

    def count_files
      ct = @doc.xpath("/OAI-PMH/GetRecord/record/metadata/item/fileContainer/file").length
      if ct.is_a?(Integer)
        return ct
      else
        Omekatools::LOG.warn("Could not get file count for #{@site.name} #{@id}")
        return 0
      end
    end

    def get_obj_type
      case @file_ct
      when 0
        Omekatools::LOG.warn("#{@site.name} #{@id} is a metadata-only record (no associated files)")
        return 'metadata'
      when 1
        return 'simple'
      else
        return 'compound'
      end
    end
  end
  
end #Omekatools
