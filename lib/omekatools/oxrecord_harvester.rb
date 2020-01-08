require 'omekatools'

module Omekatools
  class OxrecordHarvester
    def initialize(oaiuri, id, oxrecdir)
      url = "#{oaiuri}?verb=GetRecord&identifier=#{id}&metadataPrefix=omeka-xml"
      uri = URI(url)
      result = Net::HTTP.get_response(uri)

      case result
      when Net::HTTPSuccess then
        idpiece = id.sub(/^.*omeka\.net:/, '')
        outfile = "#{oxrecdir}/#{idpiece}.xml"
        File.open(outfile, 'w'){ |f|
          f.write(result.body)
        }
      else
        Omekatools::LOG.error("Problem getting record at #{url} -- #{result.code} : #{result.message}")
      end
    end
    
  end
end
