require 'json-schema'
require 'open-uri'
#rake lb2geo:create_geobl_schema
module GeoblMethods

  def self.process_simple(level,environ)
    #see find_each vs each(w/limit)
    #http://www.webascender.com/Blog/ID/553/Rails-Tips-for-Speeding-up-ActiveRecord-Queries#.WIacqrGZO1s
    Geoobject.where(level: level).order(:orig_date).limit(2).each do |go|
    #Geoobject.where(level: level).order(:orig_date).find_each do |go|
      puts "processing #{go.oid}"
      get_md = GetLadybirdMetadata.new(go.oid)
      #get_md.print_results(get_md.concat_results)
      solr_doc = get_md.create_solr(get_md.concat_results,get_md.get_geoobject,environ)
      puts "json: #{solr_doc.inspect}"
      #puts "json: #{get_md.document(solr_doc).inspect}"
    end
  end
  class GetLadybirdMetadata
    attr_accessor :oid
    attr_accessor :strings
    attr_accessor :lstrings
    attr_accessor :acids

    GEOBLACKLIGHT_RELEASE_VERSION = 'v1.1.2'.freeze
    GEOBLACKLIGHT_SCHEMA = JSON.parse(open("https://raw.githubusercontent.com/geoblacklight/geoblacklight/#{GEOBLACKLIGHT_RELEASE_VERSION}/schema/geoblacklight-schema.json").read).freeze

    def initialize(oid)
      @oid = oid
      @strings = "select a.handle, b.fdid,b.value " +
          "from field_definition a, c12_strings b " +
          "where oid = #{@oid} and a.fdid=b.fdid order by handle"

      @lstrings = "select a.handle, b.fdid,b.value " +
          "from field_definition a, c12_longstrings b " +
          "where oid = #{@oid} and a.fdid=b.fdid order by handle"

      @acids = "select a.handle, b.fdid,c.value " +
          "from field_definition a, c12_acid b, acid c " +
          "where oid = #{@oid} and a.fdid=b.fdid and b.acid = c.acid order by handle"
    end

    def get_geoobject
      go = Geoobject.where(oid: @oid)
      go[0]
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

    def create_solr(lbfields,go,environ)
      if environ == "test"
        handle = go.test_handle
      elsif environ == "prod"
        handle = go.prod_handle
      end
      if handle
        layer_slug = "yale-#{handle.split("/")[1]}" if handle
      end
      solr_json = {
          geoblacklight_version: "1.0",
          dc_identifier_s: "http://hdl.handle.net/#{handle}",
          layer_slug_s: layer_slug,
          dc_title_s: create_value(lbfields,70),
          solr_geom: create_envelope(lbfields),
          dct_provenance_s: "Yale",
          dc_rights_s: create_rights(lbfields),
          dc_description_s: create_value(lbfields,87),
          dc_creator_sm: create_values(lbfields,69),
          dc_language_s: create_value(lbfields,84),
          dc_publisher: create_value(lbfields,69),
          dc_subject_sm: create_values(lbfields,90),
          dct_spatial_sm: create_spatial(lbfields),
          dct_temporal_sm: create_values(lbfields,79),
          layer_modified_dt: go.orig_date.strftime('%Y-%m-%dT%H-%M-%SZ'),
          layer_id_s: handle,
          dct_references_s: create_dct_references(go),
          dc_format_s: create_value(lbfields,157),
          dct_issued_dt: Time.now.strftime('%Y-%m-%dT%H-%M-%SZ')
      }
      solr_json
    end
    #response.find {|x| x['label'] == 'cat' }
    #http://stackoverflow.com/questions/3419050/ruby-select-a-hash-from-inside-an-array
    #https://github.com/geoblacklight/geoblacklight/wiki/Schema#external-services
    #https://github.com/projecthydra-labs/geo_concerns/blob/master/app/services/geo_concerns/discovery/geoblacklight_document.rb
    #dc_identifier_s http://hdl.handle.net/10079.1/31zg5jv
    #layer_slug_s yale-31zg5jv
    #dc_title_s "handle"=>"Title", "fdid"=>70, "value"=>"Derby, Conn."
    #solr_geom "ENVELOPE(290,291,292,293)"
    #dct_provenance_s "Yale"
    #dc_rights_s "Item Permission ", "fdid"=>180, "value"=>"Open Access"=>"Public"
    #dc_description_s "handle"=>"Abstract", "fdid"=>87, "value"=>"Sanborn...
    #dc_creator_sm handle"=>"Creator", "fdid"=>69, "value"=>"Sanborn Map
    #dc_language_s "handle"=>"Language", "fdid"=>84, "value"=>"English"}
    #dc_publisher_s same as creator?
    #dc_subject_sm fdid 90 (91,92,294,295,296,297)?
    #dct_spatial_sm 294,295,296,297
    #dct_temporal_sm 79
    #solr_year_i parse 79.first or skip
    #layer_modified_dt orig_date from geoobjects
    #layer_id_s test_handle|prod_handle from geoobjects
    #dct_references_s http://iiif.io/api/image http://schema.org/url http://www.loc.gov/mods/v3 (oid and hydraid)
    #layer_geom_type_s fdid 99 cartographic=>Scanned Map
    #dc_format_s fdid"=>157 (image/tiff)?
    #dct_issued_dt now() ?
    #
    #is_part_of? layer_level

    def create_envelope(lbfields)
      return unless lbfields.find { |x| x["fdid"]==290} &&
          lbfields.find { |x| x["fdid"]==291} &&
          lbfields.find { |x| x["fdid"]==292} &&
          lbfields.find { |x| x["fdid"]==293}
      "ENVELOPE(#{lbfields.find { |x| x["fdid"]==290}["value"]}," +
            "#{lbfields.find { |x| x["fdid"]==291}["value"]}," +
            "#{lbfields.find { |x| x["fdid"]==292}["value"]}," +
            "#{lbfields.find { |x| x["fdid"]==292}["value"]})"
    end

    def create_rights(lbfields)
      return unless lbfields.find { |x| x["fdid"]==180}
      if lbfields.find { |x| x["fdid"]==180}["value"] == "Open Access"
        return "Public"
      else
        return "Restricted"
      end
    end

    def create_value(lbfields,fdid)
      return unless lbfields.find { |x| x["fdid"]==fdid}
      lbfields.find { |x| x["fdid"]==fdid}["value"]
    end

    def create_values(lbfields,fdid)
      return unless lbfields.find { |x| x["fdid"]==fdid}
      fields = lbfields.select { |x| x["fdid"]==fdid}
      a = Array.new
      fields.each { |x| a.push(x["value"])}
      a
    end

    def create_spatial(lbfields)
      a = Array.new
      a.push(lbfields.find { |x| x["fdid"]==294}["value"]) if lbfields.find { |x| x["fdid"]==294}
      a.push(lbfields.find { |x| x["fdid"]==295}["value"]) if lbfields.find { |x| x["fdid"]==295}
      a.push(lbfields.find { |x| x["fdid"]==296}["value"]) if lbfields.find { |x| x["fdid"]==296}
      a.push(lbfields.find { |x| x["fdid"]==297}["value"]) if lbfields.find { |x| x["fdid"]==297}
      a
    end

    def create_dct_references(go)
      iiif = "http://myiiifserver"
      schema_url = "http://myurl"
      mods = "http://mymods"
      "{\"http://iiif.io/api/image\":\"#{iiif}\",\"http://schema.org/url\":\"#{schema_url}\",\"http://www.loc.gov/mods/v3\":\"#{mods}\"}"
    end

    def document(solr_doc)
      clean = clean_document(solr_doc)
      if valid?(clean)
        clean
      else
        schema_errors(clean)
      end
    end

    def schema
      GEOBLACKLIGHT_SCHEMA
    end

    def valid?(doc)
      JSON::Validator.validate(schema, doc, fragment: '#/properties/layer')
    end

    def schema_errors(doc)
      { error: JSON::Validator.fully_validate(schema, doc, fragment: '#/properties/layer') }
    end

    def clean_document(hash)
      hash.delete_if do |_k, v|
        begin
          v.nil? || v.empty?
        rescue
          false
        end
      end
    end

  end
end