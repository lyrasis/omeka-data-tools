require 'omeka_tools'

module OmekaTools
  
  class Set
    attr_reader :repo
    attr_reader :name
    attr_reader :spec
    attr_reader :desc
    attr_reader :set_dir
    attr_reader :desc_file

    def initialize(set, repo)
      @repo = repo
      @name = set.name
      @spec = set.spec
      @desc = set.description
      @set_dir = "#{repo.repo_dir}/#{@spec}"
      @desc_file = "#{@set_dir}/#{@spec}_DC.xml"
      make_dir
      write_metadata
    end

    private

    def make_dir
      Dir::mkdir(@set_dir) unless Dir::exist?(@set_dir)
    end

    def write_metadata
      if @desc
        dc = @desc[1]
        title = REXML::Element.new('dc:title')
        title.text = @name
        dc.add_element(title)
        File.open(@desc_file, 'w') { |f| f.write(@desc) } unless File::exist?(@desc_file)
      else
        OmekaTools::LOG.warn "#{@repo.name} set #{@spec} (#{@name}) has NO DESCRIPTION"
      end

    end # write_metadata
  end # class Set

end
