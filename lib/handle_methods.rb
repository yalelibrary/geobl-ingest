require 'savon'
module HandleMethods

  def self.save_handles(environ)
    if environ == "test"
      Geoobject.where(test_handle: nil).find_each do |go|
        puts "For oid #{go.oid}"
        handle = self.get_handle(environ)
        puts "Saving handle #{handle}"
        go.test_handle = handle
        go.save!
        puts "Saved"
      end
    elsif environ == "prod"
      Geoobject.where(test_handle: nil).find_each do |go|
        puts "For oid #{go.oid}"
        handle = self.get_handle(environ)
        puts "Saving handle #{handle}"
        go.prod_handle = handle
        go.save!
        puts "Saved"
      end
    end
  end

  def self.save_handle(environ)
    if environ == "test"
      #go = Geoobject.where(level: 1,test_handle: nil).take
      go = Geoobject.where(test_handle: nil).take
      handle = self.get_handle(environ)
      go.test_handle = handle
      go.save!
    elsif environ == "prod"
      go = Geoobject.where(prod_handle: nil).take
      handle = self.get_handle(environ)
      go.prod_handle = handle
      go.save!
    end
    puts "added #{handle} to #{go.oid}"
    puts "go: #{go.inspect}"
  end

  def self.test_envelope
    "<env:Envelope xmlns:env=\"http://schemas.xmlsoap.org/soap/envelope/\">"+
        "<env:Body>"+
        "<tns:createBatch xmlns:tns=\"http://ws.ypls.odai.yale.edu/\">"+
        "<values><item>"+HandleBase+"</item></values>"+
        "<group>"+HandleTestGroup+"</group>"+
        "<user>"+HandleTestUser+"</user>"+
        "<credential>"+HandleTestCredential+"</credential>"+
        "</tns:createBatch></env:Body></env:Envelope>"
  end

  def self.prod_envelope
    "<env:Envelope xmlns:env=\"http://schemas.xmlsoap.org/soap/envelope/\">"+
        "<env:Body>"+
        "<tns:createBatch xmlns:tns=\"http://ws.ypls.odai.yale.edu/\">"+
        "<values><item>"+HandleBase+"</item></values>"+
        "<group>"+HandleProdGroup+"</group>"+
        "<user>"+HandleProdUser+"</user>"+
        "<credential>"+HandleProdCredential+"</credential>"+
        "</tns:createBatch></env:Body></env:Envelope>"
  end

  def self.create_handle(environ)
    if environ == "prod"
      response = SavonProdClient.call(:create_batch, xml: self.prod_envelope)
    elsif environ == "test"
      response = SavonTestClient.call(:create_batch, xml: self.test_envelope)
    end
    if response.success? == true
      puts "Success creating handle"
      puts "response: " + response.to_xml.to_s
    else
      puts "Error creating handle"
      puts "response: " + response.to_xml.to_s
    end
    response.to_xml.to_s
  end

  def self.get_handle(environ)
    response_xml = self.create_handle(environ)
    xml_doc = Nokogiri::XML(response_xml)
    key = xml_doc.xpath('//key').first.text()
    key
  end
end