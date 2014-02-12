# -*- encoding : utf-8 -*-

require 'rails/generators'

def yes_with_banner?(message, banner = "*" * 80)
  yes?("\n#{banner}\n\n#{message}\n#{banner}\nType y(es) to confirm:")
end

class Curate::SearchConfigGenerator < Rails::Generators::Base

  source_root Rails.root

  desc """
This generator makes the following changes:
 1. Optionally enables partial searches in SOLR schema using EdgeNGram filtered fields
 2. Optionally creates a new field in SOLR schema to aggregate metadata fields via a CopyField
 3. Optionally copies resulting SOLR configuration files to packaged Jetty (if exists)
"""

NGRAM_QUESTION =
<<-QUESTION_TO_ASK
Would you like to enable partial term matches for searches in your SOLR configuration?
 
This will create a new field type using EdgeNGram filters, which might impact index sizes.
QUESTION_TO_ASK

TEXT_QUESTION =
<<-QUESTION_TO_ASK
Would you like to create an aggregated index field in your SOLR configuration
for keyword searches?
 
This will instruct SOLR to copy a configurable list of fields into a single
field for keyword searching instead of searching fields individually.
QUESTION_TO_ASK

JETTY_SOLR_QUESTION =
<<-QUESTION_TO_ASK
Would you like to enable these SOLR configuration options in the local Jetty
instance installed with Curate?

This will copy the resulting configuration files from solr_conf/conf to the SOLR
instance inside of the included Jetty server.
QUESTION_TO_ASK

EDGE_FILTER_CONFIG =
<<-CONFIG_BLOCK
    <!-- The following definition was created during Curate installation -->
    <!-- A text field with EdgeNGram filtering for partial matches -->
    <fieldType name="text_en_ef" class="solr.TextField" positionIncrementGap="100">
      <analyzer type="index">
        <tokenizer class="solr.ICUTokenizerFactory"/>
        <filter class="solr.ICUFoldingFilterFactory"/>  <!-- NFKC, case folding, diacritics removed -->
        <filter class="solr.EnglishPossessiveFilterFactory"/>
        <!-- EnglishMinimalStemFilterFactory is less aggressive than PorterStemFilterFactory: -->
        <filter class="solr.EnglishMinimalStemFilterFactory"/>
        <filter class="solr.TrimFilterFactory"/>
        <filter class="solr.EdgeNGramFilterFactory" minGramSize="3" maxGramSize="15" side="front"/>
      </analyzer>
      <analyzer type="query">
        <tokenizer class="solr.ICUTokenizerFactory"/>
        <filter class="solr.ICUFoldingFilterFactory"/>  <!-- NFKC, case folding, diacritics removed -->
        <filter class="solr.EnglishPossessiveFilterFactory"/>
        <!-- EnglishMinimalStemFilterFactory is less aggressive than PorterStemFilterFactory: -->
        <filter class="solr.EnglishMinimalStemFilterFactory"/>
        <filter class="solr.TrimFilterFactory"/>
      </analyzer>
    </fieldType>

CONFIG_BLOCK

AGGREGATE_CONFIG =
<<-CONFIG_BLOCK
    <!-- The following definition was created during Curate installation -->
    <!-- The all_text_tesim field is an aggregate of all *_tesim fields for overall keyword searching -->
    <!-- desc_metadata_name_ef is an alternate source for people names that has been edge filtered -->
    <field name="all_text_tesim" type="text_en_ef" stored="true" indexed="true" multiValued="true"/>
    <field name="desc_metadata_name_ef" type="text_en_ef" stored="true" indexed="true" multiValued="true"/>

CONFIG_BLOCK

COPYFIELD_CONFIG =
<<-CONFIG_BLOCK

    <!-- The following definition was created during Curate installation -->
    <!-- Maintain aggregate of *_tesim fields in all_text_tesim field -->
    <copyField source="*_tesim" dest="all_text_tesim"/>
    <!-- Maintain an alternate source for people names that has been edge filtered -->
    <copyField source="desc_metadata__name_tesim" dest="desc_metadata_name_ef"/>

CONFIG_BLOCK

FINAL_STATUS = 
<<-BLOCK
Optional SOLR configuration complete. 

Please review files in ./solr_conf/conf. Changes are commented with the phrase
'created during Curate installation'. If you are using an external instance of
SOLR or chose not to copy resulting files to Jetty, then you must review/copy
the configuration files appropriately for your situation.
BLOCK

  def config_edge_filters
    myfile = Rails.root.join("solr_conf","conf","schema.xml")
    config_target = /.*A text field with defaults appropriate for English --\>\n/
    if yes_with_banner?(NGRAM_QUESTION)
      say_status(".....", "Configuring SOLR to enable EdgeNGramFilterFactory fields", :green)
      say_status(".....", "Making changes to "+myfile.to_s, :green)
      inject_into_file myfile, EDGE_FILTER_CONFIG, before: config_target
    end
  end

  def config_aggregate
    myschema = Rails.root.join("solr_conf","conf","schema.xml")
    myconfig = Rails.root.join("solr_conf","conf","solrconfig.xml")
    schema_target = /.*\<\/fields\>.*\n/
    schema_target = /.*\<\/fields\>.*\n/
    if yes_with_banner?(TEXT_QUESTION)
      say_status(".....", "Configuring SOLR to aggregate fields for keyword searches", :green)
      say_status(".....", "About to make changes to "+myschema.to_s+" and "+myconfig.to_s, :green)
      inject_into_file myschema, AGGREGATE_CONFIG, before: schema_target
      inject_into_file myschema, COPYFIELD_CONFIG, after: schema_target
      inject_into_file myconfig, "          all_text_tesim\n", after: /.*\<str name="qf"\>\n.*id\n/
      inject_into_file myconfig, "          all_text_tesim^10\n", after: /.*\<str name="pf"\>\n/
    end
  end

  def copy_solr_configs
    my_solr_path = "solr_conf/conf"  
    my_jetty_dev_path = Rails.root.join("jetty","solr","development-core","conf")
    my_jetty_test_path = Rails.root.join("jetty","solr","test-core","conf")
    if File.directory?(Rails.root+"jetty")
      if yes_with_banner?(JETTY_SOLR_QUESTION)
        say_status(".....", "Copying SOLR config files to Jetty", :green)
        copy_file my_solr_path+"/schema.xml", my_jetty_dev_path+"schema.xml", force: true
        copy_file my_solr_path+"/schema.xml", my_jetty_test_path+"schema.xml", force: true
        copy_file my_solr_path+"/solrconfig.xml", my_jetty_dev_path+"solrconfig.xml", force: true
        copy_file my_solr_path+"/solrconfig.xml", my_jetty_test_path+"solrconfig.xml", force: true
      end
    end
  end

  def final_status
    banner = "\n" + "*" * 80 + "\n"
    puts banner
    say_status("Finished",FINAL_STATUS, :green)
    puts banner
  end
end
