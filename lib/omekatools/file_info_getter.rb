require 'omekatools'

module Omekatools
  class FileInfoGetter
    attr_reader :apiurl
    attr_reader :origname
    attr_reader :obj
    attr_reader :tn
    attr_reader :mimetype

    def get_file_info
      url = URI(@apiurl)
      response = Net::HTTP.get_response(url)
      case response
      when Net::HTTPSuccess, Net::HTTPRedirection
        fileinfo = JSON.parse(response.body)
        @origname = fileinfo['original_filename']
        @obj = fileinfo['file_urls']['original']
        @tn = fileinfo['file_urls']['thumbnail']
        @mimetype = fileinfo['mime_type']
      else
        Omekatools::LOG.error("Could not get file information from #{url}")
      end
    end
  end #FileInfoGetter

  #given file id of child of compound object, gets file info
  class ChildFileInfoGetter < FileInfoGetter
    def initialize(api, fileid)
      @apiurl = "#{api}/files/#{fileid}"
      get_file_info
    end
    
  end
  
  #given item id of simple object, gets file info
  class SimpleFileInfoGetter < FileInfoGetter
    def initialize(api, itemid)
      url = URI("#{api}/files?item=#{itemid}")
      response = Net::HTTP.get_response(url)
      case response
      when Net::HTTPSuccess, Net::HTTPRedirection
        fileinfo = JSON.parse(response.body)
        @apiurl = fileinfo.first['url']
      else
        Omekatools::LOG.error("Could not get file's API URL from #{url}")
      end
      get_file_info
    end
  end
  
end #Omekatools
