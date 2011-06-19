require "spec_helper"

module Rmre
  describe Generator do
    let(:settings) do |sett|
      sett = {:db => {:adapter => 'some_adapter',
          :database => 'db',
          :username => 'user',
          :password => 'pass'},
        :out_path => File.join(Dir.tmpdir, 'gne-test'),
        :include => ['incl1_', 'incl2_']}
    end

    let(:generator) { Generator.new(settings[:db], settings[:out_path], settings[:include]) }
    let(:tables)    { %w(incl1_tbl1 incl1_tbl2 incl2_tbl1 user processes) }

    it "should flag table incl1_tbl1 for processing" do
      generator.process?('incl1_tbl1').should be_true
    end

    it "should not flag table 'processes' for processing" do
      generator.process?('processes').should be_false
    end
    
    it "should process three tables from the passed array of tables" do
      generator.stub(:create_model)

      generator.should_receive(:create_model).exactly(3).times
      generator.create_models(tables)
    end

    it "should contain set_table_name 'incl1_tbl1' in generated source" do
      generator.stub_chain(:connection, :primary_key).and_return("id")
      generator.send(:generate_model_source, 'incl1_tbl1', []).should match(/set_table_name \'incl1_tbl1\'/)
    end

    it "should create three model files" do
      generator.stub_chain(:connection, :primary_key).and_return("id")
      generator.stub(:foreign_keys).and_return([])
      generator.create_models(tables)
      Dir.glob(File.join(generator.output_path, "*.rb")).should have(3).items
    end

    it "should create prettified file names" do
      file = double("model_file")
      file.stub(:write)

      connection = double("db_connection")
      connection.stub(:primary_key).and_return('')
      generator.stub(:connection).and_return(connection)

      File.stub(:open).and_yield(file)
      File.should_receive(:open).with(/tbl_user/, "w")
      file.should_receive(:write).with(/class TblUser/)

      generator.create_model("TBL_USERS")
    end

    it "should set primary key if PK column is not id" do
      file = double("model_file")
      file.stub(:write)

      connection = double("db_connection")
      connection.stub(:primary_key).and_return("usr_id")
      generator.stub(:connection).and_return(connection)

      File.stub(:open).and_yield(file)
      file.should_receive(:write).with(/set_primary_key :usr_id/)

      generator.create_model("users")
    end
    
  end
end
