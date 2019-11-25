require 'omeka_tools'

module OmekaTools
  class Record
    attr_reader :repo # OAI repo to which record belongs
    attr_reader :id # just numeric part of the OAI ID, for use within repo/set
    attr_reader :doc # Nokogiri XML document, with namespaces removed
    attr_reader :file_ct # Count of associated files
    attr_reader :obj_type # metadata (no files); simple (1 file); compound (>1 files)

    def initialize(repo, path)
      @repo = repo
      @id = File.basename(path).sub('.xml', '')
      @doc = Nokogiri::XML(File.open(path)).remove_namespaces!
      @file_ct = count_files
      @obj_type = get_obj_type
    end

    private

    def count_files
      ct = @doc.xpath("/OAI-PMH/GetRecord/record/metadata/item/fileContainer/file").length
      if ct.is_a?(Integer)
        return ct
      else
        OmekaTools::LOG.warn("Could not get file count for #{@repo.name} #{@id}")
        return 0
      end
    end

    def get_obj_type
      case @file_ct
      when 0
        OmekaTools::LOG.warn("#{@repo.name} #{@id} is a metadata-only record (no associated files)")
        return 'metadata'
      when 1
        return 'simple'
      else
        return 'compound'
      end
    end
    
  end #Record class
end #OmekaTools
