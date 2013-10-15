# properties datastream: catch-all for info that didn't have another home.
class PropertiesDatastream < ActiveFedora::OmDatastream
  set_terminology do |t|
    t.root(:path=>"fields" ) 
    # This is where we put the user id of the object depositor
    t.depositor index_as: :stored_searchable
    t.owner

    # Although we aren't using these fields, they are required because sufia-models delegates to them.
    t.relative_path 
    t.import_url 
  end

  def self.xml_template
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.fields
    end
    builder.doc
  end
end
