module GeoblMethods

  def self.process_simple(level)
    #see find_each vs each(w/limit)
    #http://www.webascender.com/Blog/ID/553/Rails-Tips-for-Speeding-up-ActiveRecord-Queries#.WIacqrGZO1s
    Geoobject.where(level: level).order(:orig_date).limit(2).each do |go|
      puts "processing #{go.oid}"
      get_md = GetLadybirdMetadata.new(go.oid)
      get_md.print_results(get_md.concat_results)
    end
  end
  class GetLadybirdMetadata
    attr_accessor :oid
    attr_accessor :strings
    attr_accessor :lstrings
    attr_accessor :acids

    def initialize(oid)
      @oid = oid
      @strings = "select a.handle, b.fdid,b.value " +
          "from field_definition a, c12_strings b " +
          "where oid = #{@oid} and a.fdid=b.fdid order by handle"

      @lstrings = "select a.handle, b.fdid,b.value " +
          "from field_definition a, c12_strings b " +
          "where oid = #{@oid} and a.fdid=b.fdid order by handle"

      @acids = "select a.handle, b.fdid,c.value " +
          "from field_definition a, c12_acid b, acid c " +
          "where oid = #{@oid} and a.fdid=b.fdid and b.acid = c.acid order by handle"
    end

    def get_results(query)
      ds = SQLServer.execute(query)
      dsArr = Array.new
      ds.each do |i|
        dsArr.push(i)
      end
      ds.cancel
      dsArr
    end

    def concat_results
      strings_returned = get_results(@strings)
      lstrings_returned = get_results(@lstrings)
      acids_returned = get_results(@acids)
      all_returned = strings_returned + lstrings_returned + acids_returned
    end
    def print_results(all_returned)
      puts "----"
      all_returned.each do |val|
        puts " obj: #{val.inspect}"
      end
    end
  end
end