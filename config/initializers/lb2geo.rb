config = YAML.load_file('config/setup.yml')

lbuser = config.fetch("username").strip
lbpw = config.fetch("password").strip
lbhost = config.fetch("host").strip
lbdb = config.fetch("database").strip

::SQLServer = TinyTds::Client.new(:username => lbuser,:password => lbpw,:host => lbhost,:database => lbdb)

HandleProdWsdl = config.fetch("handle_prod_wsdl").strip
HandleProdGroup = config.fetch("handle_prod_group").strip
HandleProdUser = config.fetch("handle_prod_user").strip
HandleProdCredential = config.fetch("handle_prod_credential").strip

HandleTestWsdl = config.fetch("handle_test_wsdl").strip
HandleTestGroup = config.fetch("handle_test_group").strip
HandleTestUser = config.fetch("handle_test_user").strip
HandleTestCredential = config.fetch("handle_test_credential").strip

HandleBase = config.fetch("handle_test_credential").strip

::SavonProdClient = Savon.client(wsdl: HandleProdWsdl)
::SavonTestClient = Savon.client(wsdl: HandleTestWsdl)

EFSVolume = config.fetch("efs_volume").strip

SolrGeoblacklight = config.fetch("solr_geoblacklight").strip