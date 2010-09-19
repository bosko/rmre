require "spec_helper"

module ModelGenerator
  describe Generator do
    let(:settings) do |sett|
      sett = {:adapter => 'some_adapter',
        :database => 'db',
        :username => 'user',
        :password => 'pass'}
    end
    
    let(:generator) { Generator.new(settings) }
    let(:prefixes)  { %w(incl1_ incl2_) }
    let(:tables)    { %w(incl1_tbl1 incl1_tbl2 incl2_tbl1 user processes) }
    
    it "should flag table inv_plan for processing" do
      generator.process?('incl1_tbl1', prefixes).should be_true
    end

    it "should not flag table shkprocesses for processing" do
      generator.process?('processes', prefixes).should be_false
    end

    it "should process three tables from the passed array of tables" do
      generator.stub(:create_model)

      generator.should_receive(:create_model).exactly(3).times
      generator.create_models(tables, prefixes)
    end

    it "should contain set_table_name 'incl1_tbl1' in generated source" do
      generator.generate_model_source('incl1_tbl1').should match(/set_table_name \'incl1_tbl1\'/)
    end
    
    it "should create three model files" do
      generator.create_models(tables, prefixes)
      Dir.glob(File.join(generator.output_path, "*.rb")).should have(3).items
    end
  end
end
