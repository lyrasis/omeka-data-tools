require 'omekatools'

module Omekatools
  class ObjectHarvester

    def initialize(site, pointer)
      rec = JSON.parse(File.read("#{site.migrecdir}/#{pointer}.json"))
      url = rec['migfind']
      filetype = rec['migfiletype'].downcase
      filename = "#{pointer}.#{filetype}"
      path = "#{site.objdir}/#{filename}"

      if File.exist?(path)
        Omekatools::LOG.debug("OBJECT HARVESTING: #{path} exists. Skipping re-download")
      else
        response = Net::HTTP.get_response(URI(url))
        if response.is_a?(Net::HTTPSuccess)
          File.open(path, 'wb'){ |f| f.write(response.body) }
          sleep(1)
        else
          Omekatools::LOG.error("Could not harvest object file for: #{site.name}/#{pointer}")
        end
      end
    end
  end #Record class

end #module
