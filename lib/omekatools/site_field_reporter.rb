require 'omekatools'

module Omekatools
  class SiteFieldReporter
    attr_reader :site
    
    def initialize(openedfile, siteobject)
      @site = siteobject
      field_data = get_fields_from_migrecs
      field_data.each{ |field| openedfile << field }
    end

    private

    # returns array of [site, fieldname] arrays suitable for writing to CSV
    def get_fields_from_migrecs
      allfields = [] #gather field names from all records
      @site.set_migrecs
      @site.migrecs.each{ |recpath|
        rec = Omekatools::MigRecord.new(@site, "#{@site.migrecdir}/#{recpath}")
        allfields << rec.fields
      }
      uniqfields = allfields.flatten.uniq
      uniqfields.map!{ |field| [@site.name, field] }
    end
    

  end #SiteFieldReporter  
end #Omekatools
