require 'spec_helper'

include TablePrint

describe Fingerprinter do
  let(:config) { TablePrint::Config.new }

  describe "#lift" do
    it "turns a single level of columns into a single row" do
      columns = [Column.new(:name => "name")]
      table = Fingerprinter.new(config, columns).lift([OpenStruct.new(:name => "dale carnegie")])

      expect(
        table.data_equal(
          Table.new.add_child(
            RowGroup.new.add_child(
              Row.new.set_cell_values({'name' => 'dale carnegie'})
            )
          )
        )
      ).to be_true
    end

    it "attaches the config to the table" do
      columns = [Column.new(:name => "name")]

      c2 = TablePrint::Config.new
      expect(c2.object_id).not_to eq(config.object_id)

      table = Fingerprinter.new(c2, columns).lift([OpenStruct.new(:name => "dale carnegie")])

      expect(table.config.object_id).to eq(c2.object_id)
    end

    it "uses the display_method to get the data" do
      columns = [Column.new(:name => "name of work", :display_method => "title")]
      table = Fingerprinter.new(config, columns).lift([OpenStruct.new(:title => "of mice and men")])

      expect(
        table.data_equal(
          Table.new.add_child(
            RowGroup.new.add_child(
              Row.new.set_cell_values({'name of work' => 'of mice and men'})
            )
          )
        )
      ).to be_true
    end

    it "turns multiple levels of columns into multiple rows" do
      columns = [Column.new(:name => "name"), Column.new(:name => "books.title")]
      table = Fingerprinter.new(config, columns).lift([OpenStruct.new(:name => "dale carnegie", :books => [OpenStruct.new(:title => "how to make influences")])])

      expect(
        table.data_equal(
          Table.new.add_child(
            RowGroup.new.add_child(
              Row.new.set_cell_values({'name' => 'dale carnegie'}).add_child(
                RowGroup.new.add_child(
                  Row.new.set_cell_values({'books.title' => "how to make influences"})
                )
              )
            )
          )
        )
      ).to be_true
    end

    it "doesn't choke if an association doesn't exist" do
      columns = [Column.new(:name => "name"), Column.new(:name => "books.title")]
      table = Fingerprinter.new(config, columns).lift([OpenStruct.new(:name => "dale carnegie", :books => [])])

      expect(
        table.data_equal(
          Table.new.add_child(
            RowGroup.new.add_child(
              Row.new.set_cell_values({'name' => 'dale carnegie'})
            )
          )
        )
      ).to be_true
    end

    it "allows a lambda as the display_method" do
      columns = [Column.new(:name => "name", :display_method => lambda { |row| row.name.gsub(/[aeiou]/, "") })]
      table = Fingerprinter.new(config, columns).lift([OpenStruct.new(:name => "dale carnegie")])

      expect(
        table.data_equal(
          Table.new.add_child(
            RowGroup.new.add_child(
              Row.new.set_cell_values({'name' => 'dl crng'})
            )
          )
        )
      ).to be_true
    end

    it "doesn't puke if a lambda returns nil" do
      columns = [Column.new(:name => "name", :display_method => lambda { |row| nil })]
      table = Fingerprinter.new(config, columns).lift([OpenStruct.new(:name => "dale carnegie")])

      expect(
        table.data_equal(
          Table.new.add_child(
            RowGroup.new.add_child(
              Row.new.set_cell_values({'name' => nil})
            )
          )
        )
      ).to be_true
    end
  end

  describe "#hash_to_rows" do
    it "uses hashes with empty values as column names" do
      f = Fingerprinter.new(config, [Column.new(:name => "name")])
      rows = f.hash_to_rows("", {'name' => {}}, OpenStruct.new(:name => "dale carnegie"))
      rows.length.should == 1
      row = rows.first
      row.children.length.should == 0
      row.cells.should == {'name' => 'dale carnegie'}
    end

    it 'recurses for subsequent levels of hash' do
      f = Fingerprinter.new(config, [Column.new(:name => "name"), Column.new(:name => "books.title")])
      rows = f.hash_to_rows("", {'name' => {}, 'books' => {'title' => {}}}, [OpenStruct.new(:name => 'dale carnegie', :books => [OpenStruct.new(:title => "hallmark")])])
      rows.length.should == 1

      top_row = rows.first
      top_row.cells.should == {'name' => 'dale carnegie'}
      top_row.children.length.should == 1
      top_row.children.first.child_count.should == 1

      bottom_row = top_row.children.first.children.first
      bottom_row.cells.should == {'books.title' => 'hallmark'}
    end
  end

  describe "#populate_row" do
    it "fills a row by calling methods on the target object" do
      f = Fingerprinter.new(config, [Column.new(:name => "title"), Column.new(:name => "author")])
      row = f.populate_row("", {'title' => {}, 'author' => {}, 'publisher' => {'address' => {}}}, OpenStruct.new(:title => "foobar", :author => "bobby"))
      row.cells.should == {'title' => "foobar", 'author' => 'bobby'}
    end

    it "uses the provided prefix to name the cells" do
      f = Fingerprinter.new(config, [Column.new(:name => "bar.title"), Column.new(:name => "bar.author")])
      row = f.populate_row("bar", {'title' => {}, 'author' => {}, 'publisher' => {'address' => {}}}, OpenStruct.new(:title => "foobar", :author => "bobby"))
      row.cells.should == {'bar.title' => "foobar", 'bar.author' => 'bobby'}
    end

    it "uses the column name as the cell name but uses the display method to get the value" do
      f = Fingerprinter.new(config, [Column.new(:name => "title", :display_method => "bar.title"), Column.new(:name => "bar.author")])
      row = f.populate_row("bar", {'title' => {}, 'author' => {}, 'publisher' => {'address' => {}}}, OpenStruct.new(:title => "foobar", :author => "bobby"))
      row.cells.should == {'title' => "foobar", 'bar.author' => 'bobby'}
    end

    context 'using a hash as input_data' do
      let(:f) { Fingerprinter.new(config, [Column.new(:name => "title"), Column.new(:name => "author")]) }

      it "fills a row by calling methods on the target object" do
        input_data = {:title => 'foobar', :author => 'bobby'}
        row = f.populate_row('', {'title' => {}, 'author' => {}, 'publisher' => {'address' => {}}}, input_data)
        row.cells.should == {'title' => 'foobar', 'author' => 'bobby'}
      end

      it "fills a row by calling methods on the target object" do
        input_data = {'title' => 'foobar', 'author' => 'bobby'}
        row = f.populate_row('', {'title' => {}, 'author' => {}, 'publisher' => {'address' => {}}}, input_data)
        row.cells.should == {'title' => 'foobar', 'author' => 'bobby'}
      end
    end

    context "when the method isn't found" do
      it "sets the cell value to an error string" do
        f = Fingerprinter.new(config, [Column.new(:name => "foo")])
        row = f.populate_row('', {'foo' => {}}, Hash.new)
        row.cells.should == {'foo' => 'Method Missing'}
      end
    end
  end

  describe "#create_child_group" do
    it "adds the next level of column information to the prefix" do
      f = Fingerprinter.new(config)
      books = []

      f.should_receive(:hash_to_rows).with("author.books", {'title' => {}}, books).and_return([])
      groups = f.create_child_group("author", {'books' => {'title' => {}}}, OpenStruct.new(:name => "bobby", :books => books))
      groups.length.should == 1
      groups.first.should be_a TablePrint::RowGroup
    end
  end

  describe "#columns_to_handle" do
    it "returns hash keys that have an empty hash as the value" do
      Fingerprinter.new(config).handleable_columns({'name' => {}, 'books' => {'title' => {}}}).should == ["name"]
    end
  end

  describe "#columns_to_pass" do
    it "returns hash keys that do not have an empty hash as the value" do
      Fingerprinter.new(config).passable_columns({'name' => {}, 'books' => {'title' => {}}}).should == ["books"]
    end
  end

  describe "#chain_to_nested_hash" do
    it "turns a list of methods into a nested hash" do
      Fingerprinter.new(config).display_method_to_nested_hash("books").should == {'books' => {}}
      Fingerprinter.new(config).display_method_to_nested_hash("reviews.user").should == {'reviews' => {'user' => {}}}
    end
  end

  describe "#columns_to_nested_hash" do
    it "splits the column names into a nested hash" do
      Fingerprinter.new(config).display_methods_to_nested_hash(["books.name"]).should == {'books' => {'name' => {}}}
      Fingerprinter.new(config).display_methods_to_nested_hash(
          ["books.name", "books.publisher", "reviews.rating", "reviews.user.email", "reviews.user.id"]
      ).should == {'books' => {'name' => {}, 'publisher' => {}}, 'reviews' => {'rating' => {}, 'user' => {'email' => {}, 'id' => {}}}}
    end
  end
end
