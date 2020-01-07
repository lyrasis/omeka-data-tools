require 'omekatools'

module Omekatools
  class MigRecBuilder
    attr_reader :oxrec #the Omeka-XML record the mig record is based on
    attr_reader :objtype
    attr_reader :id #record id
    attr_reader :path #file path to mig rec
    attr_reader :desc #the descriptive metadata from the oxrec
    attr_reader :rec #the mig rec being built
    attr_reader :site #the Omeka site to which the record belongs
    
    def initialize(oxrec)
      @oxrec = oxrec.doc
      @objtype = oxrec.obj_type
      @id = oxrec.id
      @site = oxrec.site
      @path = "#{@site.migrecdir}/#{@id}.json"
      @desc = {}
      @rec = {}
      build_mig_rec

    end

    private

    def build_mig_rec
      @desc = extract_desc_metadata
      @desc.each{ |k, v| @rec[k] = v }
      @rec['migptr'] = @id
      
       case @objtype
       when 'simple'
         @rec['migobjlevel'] = 'top'
         @rec['migobjcategory'] = 'simple'
         fileinfo = Omekatools::SimpleFileInfoGetter.new(@site.apiuri, @id)
         Omekatools::Log.error("Cannot complete migrec for #{@site.name}/#{@id}") unless fileinfo.obj
         @rec['migfind'] = fileinfo.obj if fileinfo.obj
         @rec['migfiletype'] = fileinfo.origname.sub(/.*\./, '') if fileinfo.origname

       when 'metadata'
         @rec['migobjlevel'] = 'top'
         @rec['migobjcategory'] = 'metadata'
       when 'compound'
         @rec['migobjlevel'] = 'top'
         @rec['migobjcategory'] = 'compound'
         child_data = get_child_data
         @rec['migchilddata'] = child_data
         @rec['migchildptrs'] = child_data.keys
         child_data.each{ |id, hash|
           build_child_mig_rec(id, hash)
         }
       else
         puts "#{@site.name} #{id} - mig rec pending due to type: #{@objtype}"
       end

       write_rec(@path, @rec)
    end

    def write_rec(path, hash)
      File.open(path, 'w'){ |f|
        f.write(hash.to_json)
      }
    end

    def build_child_mig_rec(id, hash)
      child_rec = {}
      child_rec['migptr'] = id
      child_rec['title'] = hash['title']
      fileinfo = Omekatools::ChildFileInfoGetter.new(@site.apiuri, id)
      Omekatools::Log.error("Cannot complete migrec for #{@site.name}/#{id}") unless fileinfo.obj
      child_rec['identifier'] = fileinfo.origname if fileinfo.origname
      child_rec['mimetype'] = fileinfo.mimetype if fileinfo.mimetype
      child_rec['migobjlevel'] = 'child'
      child_rec['migparentptr'] = @id
      child_rec['migfind'] = fileinfo.obj if fileinfo.obj
      child_rec['migfiletype'] = fileinfo.origname.sub(/.*\./, '') if fileinfo.origname
      write_rec("#{@site.migrecdir}/#{id}.json", child_rec)
    end
    
    def get_child_data
      childdata = {}
      children = @oxrec.xpath("/OAI-PMH/GetRecord/record/metadata/item/fileContainer/*")
      ct = 0
      children.each{ |c|
        ct += 1
        id = c['fileId']
        file = c.at('src').text
        title = "#{@rec['title']} (#{ct} of #{children.length})"
        childdata[id] = {'title' => title, 'file' => file }
      }
      childdata
    end

    # returns array of S3 urls
    def extract_desc_metadata
      h = {}
      desc_section = @oxrec.xpath("/OAI-PMH/GetRecord/record/metadata/item/elementSetContainer/elementSet[name='Dublin Core']/elementContainer/*")
      if desc_section.length == 0
        Omekatools::LOG.warn("#{@site.name} #{id} Omeka-XML contains no Dublin Core description")
      else
        desc_section.each{ |field|
          fname = field.at("name").text
          vals = @oxrec.xpath("/OAI-PMH/GetRecord/record/metadata/item/elementSetContainer/elementSet[name='Dublin Core']/elementContainer/element[name='#{fname}']/elementTextContainer/*")

          valarr = []

          if vals.length == 0
            puts "NO VALUE"
            Omekatools::LOG.warn("#{@site.name} #{id} #{fname} has no values")
          else
            vals.each { |v| valarr << v.at("text").text }
          end

          h[fname.downcase] = valarr.join(';;;')
        }
      end

      h['tags'] = get_tags if get_tags
      
      return h
    end

    def get_tags
      tag_nodes = @oxrec.xpath("/OAI-PMH/GetRecord/record/metadata/item/tagContainer/*")
      if tag_nodes.length == 0
        return nil
      else
        tags = []
        tag_nodes.each{ |node|
          tags << node.at('name').text
        }
        return tags.join(';;;')
      end
    end
    
  end #MigRecBuilder

  
end #Omekatools
