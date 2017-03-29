require 'json-schema'
require 'open-uri'
require 'fileutils'
#rake lb2geo:create_geobl_schema
module GeoblMethods2

  def self.process(level,environ)
    #see find_each vs each(w/limit)
    #http://www.webascender.com/Blog/ID/553/Rails-Tips-for-Speeding-up-ActiveRecord-Queries#.WIacqrGZO1s
    Geoobject.where(level: level).order(:orig_date).limit(3).each do |go|
    #Geoobject.where(level: level).order(:orig_date).find_each do |go|
      puts "processing #{go.oid}"
      lmd = LadybirdMetadata.new(go)
      lmd.set_returned(lmd)
      lmd.print_results("OID",lmd.oid_returned)
      lmd.print_results("parentOID",lmd._oid_returned)
      lmd.save_string(go.oid,lmd.json_results("OID",lmd.oid_returned))
      #lmd.create_volume_envelope(lmd,go.oid) #just to test
      solr_doc = lmd.processto_solr(lmd,lmd.oid_returned,lmd._oid_returned,lmd.get_geoobject,environ)
      doc = lmd.document(solr_doc)
      puts "json: #{doc.inspect}"
      lmd.process_gbl_json(lmd,doc,go)
      #lmd.save_from_fedora(go.oid,go.pid) if doc[:error] == nil
      #TODO public vs private iiif s3
      #TODO copy mods from ./efs to s3
      #TODO copy jp2 from share to s3 (create bucket/download tools)->get a iiif server (Open Access, Yale Community Only)
      #TODO setup dct references
      #TODO rake task for only fixing dct references
      #TODO run all of c12
      #TODO move to AWS
    end
  end

  class LadybirdMetadata
    attr_accessor :oid
    attr_accessor :_oid
    attr_accessor :oid_returned
    attr_accessor :_oid_returned

    GEOBLACKLIGHT_RELEASE_VERSION = 'v1.1.2'.freeze
    GEOBLACKLIGHT_SCHEMA = JSON.parse(open("https://raw.githubusercontent.com/geoblacklight/geoblacklight/#{GEOBLACKLIGHT_RELEASE_VERSION}/schema/geoblacklight-schema.json").read).freeze

    def initialize(go)
      @oid = go.oid
      @_oid = go._oid
      #puts "OID #{@oid}"
      #puts "_OID #{@_oid}"
    end

    def set_returned(lmd)
      @oid_returned = lmd.returned(lmd,@oid)
      if @_oid == 0
        @_oid_returned = Array.new
      else
        @_oid_returned = lmd.returned(lmd,@_oid)
      end
    end

    def returned(lmd,oid)
      strings = "select a.handle, b.fdid,b.value " +
          "from field_definition a, c12_strings b " +
          "where oid = #{oid} and a.fdid=b.fdid order by handle"

      lstrings = "select a.handle, b.fdid,b.value " +
          "from field_definition a, c12_longstrings b " +
          "where oid = #{oid} and a.fdid=b.fdid order by handle"

      acids = "select a.handle, b.fdid,c.value " +
          "from field_definition a, c12_acid b, acid c " +
          "where oid = #{oid} and a.fdid=b.fdid and b.acid = c.acid order by handle"
      strings_returned = lmd.get_results(strings)
      lstrings_returned = lmd.get_results(lstrings)
      acids_returned = lmd.get_results(acids)
      all_returned = strings_returned + lstrings_returned + acids_returned
      all_returned
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

    def print_results(result_type,all_returned)
      puts "#{result_type}----"
      all_returned.each do |val|
        puts "#{val.inspect}"
      end
    end

    def json_results(type,all_returned)
      res = String.new
      res << "{"
      all_returned.each do |val|
        str = "\"#{val["handle"]}\" : { \"fdid\" : \"#{val["fdid"]}\", \"value\" : \"#{val["value"]}\"},"
        res << str
      end
      res.chop!
      res << "}"
      #puts "#{res}"
      res
    end

    def process_gbl_json(lmd,doc,go)
      if doc[:error] == nil
        ptdir = "#{EFSVolume}/oid/#{oid.to_i % 256}"
        FileUtils::mkdir_p ptdir
        File.open("#{ptdir}/#{go.oid}-gbl.json", 'w') { |file| file.write(doc) }
        lmd.ingest_to_solr(doc)
        go.processed = "success"
      else
        go.error = doc[:error]
        go.processed = "error"
      end
      go.save!
    end

    def processto_solr(lmd,lbfields,lbfields_parent,go,environ)
      #note: commented out as not using handle as id
      #if environ == "test"
      #  handle = go.test_handle
      #elsif environ == "prod"
      #  handle = go.prod_handle
      #end
      #if handle
      #  layer_slug = "yale-#{handle.split("/")[1]}" if handle
      #end
      oid = go.oid
      _oid = go.oid
      level = go.level
      zindex = go.zindex
      pid = go.pid

      if level == 1
        solr_json = {
          geoblacklight_version: "1.0",
          #dc_identifier_s: "http://hdl.handle.net/#{handle}",
          dc_identifier_s: "urn:yale:oid:#{oid}",
          layer_slug_s: "yale-oid-#{oid}",
          dc_title_s: create_value(lbfields,70),
          solr_geom: create_envelope(lbfields),
          dct_provenance_s: "Yale",
          dc_rights_s: create_rights(lbfields),
          dc_description_s: create_value(lbfields,87),
          dc_creator_sm: create_values(lbfields,69),
          dc_language_s: create_value(lbfields,84),
          dc_publisher_s: create_value(lbfields,69),
          dc_subject_sm: create_values(lbfields,90),
          dct_spatial_sm: create_spatial(lbfields),
          dct_temporal_sm: create_values(lbfields,79),
          layer_modified_dt: DateTime.parse(go.orig_date.to_s).utc.strftime('%FT%TZ'),
          layer_id_s: "yale-oid:#{oid}",
          dct_references_s: create_dct_references(go),
          layer_geom_type_s: create_layer_geom_type(lbfields),
          dc_format_s: create_layer_geom_type(lbfields),
          dct_issued_dt: DateTime.parse(Time.now.to_s).utc.strftime('%FT%TZ'),
          oid_i: oid,
          parent_oid_i: _oid,
          zindex_i: zindex,
          lblevel_i: level,
          hydra_id_s: pid
        }
      elsif level == 2
        solr_json = {
            geoblacklight_version: "1.0",
            #dc_identifier_s: "http://hdl.handle.net/#{handle}",
            dc_identifier_s: "urn:yale:oid:#{oid}",
            layer_slug_s: "yale-oid-#{oid}",
            dc_title_s: create_value(lbfields,70),
            solr_geom: create_volume_envelope(lmd,oid), #
            dct_provenance_s: "Yale",
            dc_rights_s: create_rights(lbfields),
            dc_description_s: create_value(lbfields,87),
            dc_creator_sm: create_values(lbfields,69),
            dc_language_s: create_value(lbfields,84),
            dc_publisher_s: create_value(lbfields,69),
            dc_subject_sm: create_values(lbfields,90),
            dct_spatial_sm: create_spatial(lbfields),
            dct_temporal_sm: create_values(lbfields,79),
            layer_modified_dt: DateTime.parse(go.orig_date.to_s).utc.strftime('%FT%TZ'),
            layer_id_s: "yale-oid:#{oid}",
            dct_references_s: create_dct_references(go),
            layer_geom_type_s: create_layer_geom_type(lbfields),
            dc_format_s: create_layer_geom_type(lbfields),
            dct_issued_dt: DateTime.parse(Time.now.to_s).utc.strftime('%FT%TZ'),
            oid_i: oid,
            parent_oid_i: _oid,
            zindex_i: zindex,
            lblevel_i: level,
            hydra_id_s: pid
        }
      elsif level == 3
        if is_index_map?(lbfields)
          solr_geom = create_volume_envelope(lmd,_oid)
          #puts "creating index map envelope #{solr_geom}"
        else
          solr_geom = create_envelope(lbfields)
          #puts "creating sheet envelope #{solr_geom}"
        end
        solr_json = {
            geoblacklight_version: "1.0",
            #dc_identifier_s: "http://hdl.handle.net/#{handle}",
            dc_identifier_s: "urn:yale:oid:#{oid}",
            layer_slug_s: "yale-oid-#{oid}",
            dc_title_s: create_value(lbfields_parent,70) + " - " + create_value(lbfields,74), #
            solr_geom: solr_geom, #
            dct_provenance_s: "Yale",
            dc_rights_s: create_rights(lbfields_parent),
            dc_description_s: create_value(lbfields_parent,87),
            dc_creator_sm: create_values(lbfields_parent,69),
            dc_language_s: create_value(lbfields_parent,84),
            dc_publisher_s: create_value(lbfields_parent,69),
            dc_subject_sm: create_values(lbfields_parent,90),
            dct_spatial_sm: create_spatial(lbfields_parent),
            dct_temporal_sm: create_values(lbfields_parent,79),
            layer_modified_dt: DateTime.parse(go.orig_date.to_s).utc.strftime('%FT%TZ'),
            layer_id_s: "yale-oid:#{oid}",
            dct_references_s: create_dct_references(go),
            layer_geom_type_s: create_layer_geom_type(lbfields_parent),
            dc_format_s: create_layer_geom_type(lbfields_parent),
            dct_issued_dt: DateTime.parse(Time.now.to_s).utc.strftime('%FT%TZ'),
            oid_i: go.oid,
            parent_oid_i: go._oid,
            zindex_i: go.zindex,
            lblevel_i: go.level,
            hydra_id_s: go.pid
        }

      end

      solr_json
    end
    #mapping comments:
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

    def ingest_to_solr(doc)
      solr = RSolr.connect :url => SolrGeoblacklight
      solr.add doc
      solr.commit
    end

    def is_index_map?(lbfields)
      return false unless lbfields.find { |x| x["fdid"]==75}
      if lbfields.find { |x| x["fdid"]==75}["value"] == "Index Map"
        return true
      else
        return false
      end
    end

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

    def create_volume_envelope(lmd,parent_oid)
      west = "select MAX(a.value) as WEST from c12_strings a, c12 b " +
          "where a.fdid = 290 and b._oid = #{parent_oid} and a.oid = b.oid"
      east = "select MIN(a.value) as EAST from c12_strings a, c12 b " +
          "where a.fdid = 291 and b._oid = #{parent_oid} and a.oid = b.oid"
      north = "select MAX(a.value) as NORTH from c12_strings a, c12 b " +
          "where a.fdid = 292 and b._oid = #{parent_oid} and a.oid = b.oid"
      south = "select MIN(a.value) as SOUTH from c12_strings a, c12 b " +
          "where a.fdid = 293 and b._oid = #{parent_oid} and a.oid = b.oid"
      wwest = lmd.get_results(west)[0]["WEST"]
      eeast = lmd.get_results(east)[0]["EAST"]
      nnorth = lmd.get_results(north)[0]["NORTH"]
      ssouth = lmd.get_results(south)[0]["SOUTH"]

      return unless !wwest.nil? && !eeast.nil? && !nnorth.nil? && !ssouth.nil?
      #puts "WEST #{wwest}"
      #puts "EAST #{eeast}"
      #puts "NORTH #{nnorth}"
      #puts "SOUTH #{ssouth}"
      envelope = "ENVELOPE(#{wwest},#{eeast},#{nnorth},#{ssouth})"
      #puts "#{envelope}"
      return envelope
    end

    def create_rights(lbfields)
      return unless lbfields.find { |x| x["fdid"]==180}
      if lbfields.find { |x| x["fdid"]==180}["value"] == "Open Access"
        return "Public"
      elsif lbfields.find { |x| x["fdid"]==180}["value"] == "Yale Community Only"
        return "Restricted"
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
      #fake variables to be replaced with real values
      iiif = "http://libimages.princeton.edu/loris2/pudl0001%2F5138415%2F00000011.jp2/info.json"
      schema_url = "http://myurl"
      mods = "http://mymods"
      "{\"http://iiif.io/api/image\":\"#{iiif}\",\"http://schema.org/url\":\"#{schema_url}\",\"http://www.loc.gov/mods/v3\":\"#{mods}\"}"
    end

    def create_layer_geom_type(lbfields)
      return unless lbfields.find { |x| x["fdid"]==99}
      if lbfields.find { |x| x["fdid"]==99}["value"] == "cartographic"
        return "Scanned Map"
      else
        return lbfields.find { |x| x["fdid"]==99}["value"] #note: these(sanborn) should all be scanned maps
      end
    end

    def save_from_fedora(oid,pid)
      ptdir = "#{EFSVolume}/oid/#{oid.to_i % 256}"
      FileUtils::mkdir_p ptdir
      open("#{ptdir}/#{oid}-mods.xml", "wb") do |file|
        open("#{Fedora}/fedora/objects/#{pid}/datastreams/descMetadata/content") do |uri|
          file.write(uri.read)
        end
      end
    end

    def save_string(oid,str)
      ptdir = "#{EFSVolume}/oid/#{oid.to_i % 256}"
      FileUtils::mkdir_p ptdir
      #puts "ptdir: #{ptdir}"
      File.open("#{ptdir}/#{oid}-ladybird.txt", 'w') { |file| file.write(str) }
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