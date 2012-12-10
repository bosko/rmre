require 'spec_helper'

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

    let(:generator) do |gen|
      gen = Generator.new(settings[:db], settings[:out_path], settings[:include])
      connection = double('db_connection')
      connection.stub(:columns).and_return([])
      gen.stub(:connection).and_return(connection)
      gen
    end
    
    let(:tables)    { %w(incl1_tbl1 incl1_tbl2 incl2_tbl1 user processes) }

    it 'should flag table incl1_tbl1 for processing' do
      generator.process?('incl1_tbl1').should be_true
    end

    it 'should not flag table \'processes\' for processing' do
      generator.process?('processes').should be_false
    end
    
    it 'should process three tables from the passed array of tables' do
      generator.stub(:create_model)

      generator.should_receive(:create_model).exactly(3).times
      generator.create_models(tables)
    end

    it 'should contain set_table_name \'incl1_tbl1\' in generated source' do
      generator.stub_chain(:connection, :primary_key).and_return('id')
      generator.send(:generate_model_source, 'incl1_tbl1', []).should match(/self\.table_name = \'incl1_tbl1\'/)
    end

    it 'should create three model files' do
      generator.stub_chain(:connection, :primary_key).and_return('id')
      generator.stub(:foreign_keys).and_return([])
      generator.create_models(tables)
      Dir.glob(File.join(generator.output_path, '*.rb')).should have(3).items
    end

    it 'should create prettified file names' do
      file = double('model_file')
      file.stub(:write)

      generator.connection.stub(:primary_key).and_return('')
      
      File.stub(:open).and_yield(file)
      File.should_receive(:open).with(/tbl_user/, 'w')
      file.should_receive(:write).with(/class TblUser/)

      generator.create_model('TBL_USERS')
    end

    context 'with non standard keys'
      before(:each) do
        @file = double('model_file')
        @file.stub(:write)
      end
      
    it 'should set primary key if PK column is not id' do
      generator.connection.stub(:primary_key).and_return('usr_id')
      File.stub(:open).and_yield(@file)
      @file.should_receive(:write).with(/self\.primary_key = :usr_id/)
      generator.create_model('users')
    end
    
    it 'should set foreign key if FK column is not id' do
      generator.connection.stub(:primary_key).and_return('post_id')
      generator.stub(:foreign_keys).and_return([
        {
        "from_table" => "posts", 
        "from_column" => "uzer_id", 
        "to_table"=>"user", 
        "to_column"=>"some_other_primary_key_id"}])
      File.stub(:open).and_yield(@file)
      @file.should_receive(:write).with(/:foreign_key => :uzer_id/)
      generator.create_model('posts')
    end
    
  end
end
