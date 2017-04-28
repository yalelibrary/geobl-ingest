require Rails.root.join('config/environment.rb')
require Rails.root.join('lib/handle_methods.rb')
require Rails.root.join('lib/geobl_methods2.rb')
Rails.logger = Logger.new("#{Rails.root}/log/ingest.log",10,200.megabytes)
Rails.logger.formatter = Logger::Formatter.new
#docker-compose run web rake lb2geo:get_c12_count
#docker-compose run web bash
namespace :lb2geo do

  #this is only a test
  desc "testing rake"
  task :test do
    puts "this is only a test"
  end

  #this is only a test
  desc "testing query to sqlserver"
  task :get_c12_count do
    puts "testsql output: #{get_c12_count}"
  end

  #this only needs to be done once per deployment
  desc "populate database from ladybird"
  task :get_c12_and_hydra_id do
    startdate = "2013-01-01"
    populate_geoobject(get_c12_and_hydra_id(startdate))
  end

  #unused, not using handles
  desc "create test handles"
  task :create_test_handles do
    HandleMethods.save_handles("test")
  end

  #unused, not using handles
  desc "create prod handles"
  task :create_test_handles do
    HandleMethods.save_handles("prod")
  end

  desc "create geoblacklight schema for test"
  task :create_geobl_schema do
    #GeoblMethods2.process(1,"test")
    #GeoblMethods2.process(2,"test")
    GeoblMethods2.process(3,"test")
  end

  #to clear solr:
  #curl http://gblsolr:8983/solr/geoblacklight/update?stream.body=<delete><query>*:*</query></delete>&commit=true

  #methods

  def get_c12_count
    ds = SQLServer.execute(%Q/select COUNT(*) as COUNT from c12/)
    dsArr = Array.new
    ds.each do |ds1|
      dsArr.push(ds1)
    end
    ds.cancel
    dsArr[0]
  end

  def get_c12_and_hydra_id(startdate)
    ds = SQLServer.execute(%Q/select a.oid, a._oid, b.date, b.hydraID, b.hcmid, a._zindex
      from c12 as a, hydra_publish as b
      where a.oid=b.oid and b.action = 'insert' and a.date > '#{startdate}'
      order by a._oid, b.date/)
    dsArr = Array.new
    ds.each do |i|
      dsArr.push(i)
    end
    ds.cancel
    dsArr
  end

  def populate_geoobject(c12_input)
    c12_input.each do |i|
      go = Geoobject.new
      go.oid = i["oid"]
      go._oid = i["_oid"]
      go.orig_date = i["date"]
      go.pid = i["hydraID"]
      go.level = i["hcmid"]
      go.zindex = i["_zindex"]
      go.save!
      puts "saved oid #{go.oid}"
    end
  end
  #select oid,_oid,level,pid,orig_date,created_at,updated_at from geoobjects where level = 1 and test_handle is null limit 1 ;

  def get_results(query)
    ds = SQLServer.execute(query)
    dsArr = Array.new
    ds.each do |i|
      dsArr.push(i)
    end
    ds.cancel
    dsArr
  end
end


