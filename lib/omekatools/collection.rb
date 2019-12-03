require 'omekatools'

module Omekatools
  
  class Collection
    attr_reader :site # omeka site of which collection is part
    attr_reader :name # collection name
    attr_reader :collid # collection id; setSpec in OAI; :id in API
    attr_reader :desc # descriptive metadata for collection
    attr_reader :coll_dir # path to directory for collection
    attr_reader :desc_file # path to descriptive metadata file
#    attr_reader :objs_by_category # hash of pointers organized under keys 'compound', 'compound pdf', and 'simple'
#    attr_reader :simpleobjs # list of pointers to simple objects in the collection
#    attr_reader :migrecs # array of migration record filenames

    
    def initialize(name, id, desc, site)
      @site = site
      @name = name
      @collid = id
      @desc = desc
      @coll_dir = "#{site.site_dir}/coll_#{@collid}"
      @desc_file = "#{@coll_dir}/_#{@collid}_DC.xml"
      @id_file = "#{@coll_dir}/_ids.txt"
      make_dir
      write_metadata unless File::exist?(@desc_file)
    end

    def to_h
      h = { 'name' => @name,
           'collid' => @collid,
           'desc' => @desc,
            'sitename' => @site.name,
            'coll_dir' => @coll_dir
          }
      if @name == @site.name && @collid == 0
        h['mockcoll'] = true
      end
      h
    end
    
    private

    def make_dir
      Dir::mkdir(@coll_dir) unless Dir::exist?(@coll_dir)
    end

    def write_metadata
      if @desc
        dc = @desc[1]
        title = REXML::Element.new('dc:title')
        title.text = @name
        dc.add_element(title)
        File.open(@desc_file, 'w') { |f| f.write(@desc) } unless File::exist?(@desc_file)
      else
        Omekatools::LOG.warn "#{@site.name} collection #{@collid} (#{@name}) has NO DESCRIPTION" if @collid != 0
      end

    end # write_metadata
  end # class Collection
end #module
