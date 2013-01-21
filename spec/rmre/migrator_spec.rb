require "spec_helper"

module Rmre
  describe Migrator do
    let(:src_connection) do |src_con|
      src_con = double("source_connection")
    end

    let(:tgt_connection) do |tgt_con|
      tgt_con = double("target_connection")
    end

    let(:src_db_opts) do |opts|
      opts = { :adapter => "fake_adapter", :database => "source_db" }
    end

    let(:tgt_db_opts) do |opts|
      opts = { :adapter => "fake_adapter", :database => "target_db" }
    end

    let(:id_column) do |col|
      col = double("id_column")
      col.stub!(:name).and_return("id")
      col.stub!(:null).and_return(false)
      col.stub!(:default).and_return(nil)
      col.stub!(:type).and_return("integer")
      col
    end

    let(:name_column) do |col|
      col = double("name_column")
      col.stub!(:name).and_return("name")
      col.stub!(:null).and_return(false)
      col.stub!(:default).and_return(nil)
      col.stub!(:type).and_return("integer")
      col
    end

    let(:table) do |tbl|
      tbl = double("created_table")
      tbl.stub!(:column)
      tbl
    end

    before(:each) do
      Source::Db.stub!(:establish_connection).and_return(true)
      Source::Db.stub!(:connection).and_return(src_connection)

      Target::Db.stub!(:establish_connection).and_return(true)
      Target::Db.stub!(:connection).and_return(tgt_connection)
    end

    context "initialization" do
      it "stores connection options in source and target modules" do
        Migrator.new(src_db_opts, tgt_db_opts)
        Source.connection_options.should be_eql(src_db_opts)
        Target.connection_options.should be_eql(tgt_db_opts)
      end

      it "passes connection options to source and target connections" do
        Source::Db.should_receive(:establish_connection).with(src_db_opts)
        Target::Db.should_receive(:establish_connection).with(tgt_db_opts)
        Migrator.new(src_db_opts, tgt_db_opts)
      end
    end

    context "copying tables" do
      before(:each) do
        src_connection.stub(:tables).and_return %w{parent_table child_table}
        src_connection.stub!(:columns).and_return([id_column, name_column])
        src_connection.stub!(:primary_key).and_return("id")

        @migrator = Migrator.new(src_db_opts, tgt_db_opts)
        @migrator.stub!(:copy_data)
      end

      it "copies all tables if they do not exist" do
        tgt_connection.should_receive(:table_exists?).exactly(2).times.and_return(false)
        tgt_connection.should_receive(:create_table).exactly(2).times
        @migrator.copy
      end

      it "doesn't copy tables if they exist" do
        tgt_connection.should_receive(:table_exists?).exactly(2).times.and_return(true)
        tgt_connection.should_not_receive(:create_table)
        @migrator.copy
      end

      it "copies existing tables if it is forced to recreate them" do
        tgt_connection.should_receive(:table_exists?).exactly(2).times.and_return(true)
        tgt_connection.should_receive(:create_table).exactly(2).times
        @migrator.copy(true)
      end
    end

    context "copying tables with 'skip existing' turned on" do
      before(:each) do
        src_connection.stub(:tables).and_return %w{parent_table child_table}
        src_connection.stub!(:columns).and_return([id_column, name_column])

        @migrator = Migrator.new(src_db_opts, tgt_db_opts, {:skip_existing => true})
      end

      it "skips existing tables" do
        tgt_connection.should_receive(:table_exists?).exactly(2).times.and_return(true)
        tgt_connection.should_not_receive(:create_table)
        @migrator.copy
      end
    end

    context "table creation" do
      before(:each) do
        @source_columns = [id_column, name_column]
      end

      context "Rails copy mode" do
        before(:each) do
          @migrator = Migrator.new(src_db_opts, tgt_db_opts)
          src_connection.stub!(:primary_key).and_return("id")
          tgt_connection.stub!(:adapter_name).and_return("fake adapter")
        end

        it "does not explicitely create ID column" do
          tgt_connection.should_receive(:create_table).with("parent", {:id => true, :force => false}).
            and_yield(table)
          table.should_not_receive(:column).with("id", anything(), anything())
          @migrator.create_table("parent", @source_columns)
        end

        it "creates other columns but ID column" do
          tgt_connection.should_receive(:create_table).with("parent", {:id => true, :force => false}).
            and_yield(table)
          table.should_receive(:column).with("name", anything(), anything())
          @migrator.create_table("parent", @source_columns)
        end
      end

      context "non-Rails copy mode" do
        before(:each) do
          @migrator = Migrator.new(src_db_opts, tgt_db_opts, {:rails_copy_mode => false})
          tgt_connection.stub!(:adapter_name).times.and_return("fake adapter")
          src_connection.stub!(:primary_key).and_return("primaryIdColumn")
        end

        it "explicitely creates ID column" do
          tgt_connection.should_receive(:create_table).with("parent",
            {:id => true, :force => false, :primary_key => "primaryIdColumn" }).
            and_yield(table)
          table.should_receive(:column).with("id", anything(), anything())
          @migrator.create_table("parent", @source_columns)
        end

        it "creates other columns too" do
          tgt_connection.should_receive(:create_table).with("parent",
            {:id => true, :force => false, :primary_key => "primaryIdColumn"}).
            and_yield(table)
          table.should_receive(:column).with("name", anything(), anything())
          @migrator.create_table("parent", @source_columns)
        end
      end
    end
  end
end
