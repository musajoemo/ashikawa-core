require 'unit/spec_helper'
require 'ashikawa-core/collection'

describe Ashikawa::Core::Collection do
  subject { Ashikawa::Core::Collection }

  before :each do
    @database = double()
    mock { Ashikawa::Core::Cursor }
  end

  it "should have a name" do
    my_collection = subject.new @database, server_response("/collections/4588")
    my_collection.name.should == "example_1"
  end

  it "should accept an ID" do
    my_collection = subject.new @database, server_response("/collections/4588")
    my_collection.id.should == 4588
  end

  describe "the status code" do
    it "should know if the collection is new born" do
      my_collection = subject.new @database, { "status" => "1" }
      my_collection.new_born?.should == true

      my_collection = subject.new @database, { "status" => "200" }
      my_collection.new_born?.should == false
    end

    it "should know if the collection is unloaded" do
      my_collection = subject.new @database, { "status" => "2" }
      my_collection.unloaded?.should == true

      my_collection = subject.new @database, { "status" => "200" }
      my_collection.unloaded?.should == false
    end

    it "should know if the collection is loaded" do
      my_collection = subject.new @database, { "status" => "3" }
      my_collection.loaded?.should == true

      my_collection = subject.new @database, { "status" => "200" }
      my_collection.loaded?.should == false
    end

    it "should know if the collection is being unloaded" do
      my_collection = subject.new @database, { "status" => "4" }
      my_collection.being_unloaded?.should == true

      my_collection = subject.new @database, { "status" => "200" }
      my_collection.being_unloaded?.should == false
    end

    it "should know if the collection is corrupted" do
      my_collection = subject.new @database, { "status" => "6" }
      my_collection.corrupted?.should == true
    end
  end

  describe "attributes of a collection" do
    it "should check if the collection waits for sync" do
      @database.stub(:send_request).with("/collection/4590/properties", {}).and_return { server_response("/collections/4590") }
      @database.should_receive(:send_request).with("/collection/4590/properties", {})

      my_collection = subject.new @database, { "id" => "4590" }
      my_collection.wait_for_sync?.should be_true
    end

    it "should know how many documents the collection has" do
      @database.stub(:send_request).with("/collection/4590/count", {}).and_return { server_response("/collections/4590-properties") }
      @database.should_receive(:send_request).with("/collection/4590/count", {})

      my_collection = subject.new @database, { "id" => "4590" }
      my_collection.length.should == 54
    end

    it "should check for the figures" do
      @database.stub(:send_request).with("/collection/73482/figures", {}).and_return { server_response("/collections/73482-figures") }
      @database.should_receive(:send_request).with("/collection/73482/figures", {}).at_least(1).times

      my_collection = subject.new @database, { "id" => "73482" }
      my_collection.figure(:datafiles_count).should == 1
      my_collection.figure(:alive_size).should      == 0
      my_collection.figure(:alive_count).should     == 0
      my_collection.figure(:dead_size).should       == 2384
      my_collection.figure(:dead_count).should      == 149
    end
  end

  describe "an initialized collection" do
    subject { Ashikawa::Core::Collection.new @database, { "id" => "4590", "name" => "example_1" } }

    it "should get deleted" do
      @database.stub(:send_request).with("/collection/4590", delete: {})
      @database.should_receive(:send_request).with("/collection/4590", delete: {})

      subject.delete
    end

    it "should get loaded" do
      @database.stub(:send_request).with("/collection/4590/load", put: {})
      @database.should_receive(:send_request).with("/collection/4590/load", put: {})

      subject.load
    end

    it "should get unloaded" do
      @database.stub(:send_request).with("/collection/4590/unload", put: {})
      @database.should_receive(:send_request).with("/collection/4590/unload", put: {})

      subject.unload
    end

    it "should get truncated" do
      @database.stub(:send_request).with("/collection/4590/truncate", put: {})
      @database.should_receive(:send_request).with("/collection/4590/truncate", put: {})

      subject.truncate!
    end

    it "should change if it waits for sync" do
      @database.stub(:send_request).with("/collection/4590/properties", put: {"waitForSync" => true})
      @database.should_receive(:send_request).with("/collection/4590/properties", put: {"waitForSync" => true})

      subject.wait_for_sync = true
    end

    it "should change its name" do
      @database.stub(:send_request).with("/collection/4590/rename", put: {"name" => "my_new_name"})
      @database.should_receive(:send_request).with("/collection/4590/rename", put: {"name" => "my_new_name"})

      subject.name = "my_new_name"
    end

    describe "working with documents" do

      describe "add and get single documents" do
        it "should receive a document by ID" do
          @database.stub(:send_request).with("/document/4590/333").and_return { server_response('documents/4590-333') }
          @database.should_receive(:send_request).with("/document/4590/333")

          # Documents need to get initialized:
          Ashikawa::Core::Document.should_receive(:new)

          subject[333]
        end

        it "should replace a document by ID" do
          @database.stub(:send_request).with("/document/4590/333", put: {"name" => "The Dude"})
          @database.should_receive(:send_request).with("/document/4590/333", put: {"name" => "The Dude"})

          subject[333] = {"name" => "The Dude"}
        end

        it "should create a new document" do
          @database.stub(:send_request).with("/document?collection=4590", post: { "name" => "The Dude" }).and_return do
            server_response('documents/new-4590-333')
          end
          @database.stub(:send_request).with("/document/4590/333", post: { "name" => "The Dude" }).and_return { server_response('documents/4590-333') }

          # Documents need to get initialized:
          Ashikawa::Core::Document.should_receive(:new)

          subject.create({"name" => "The Dude"})
        end

        it "should create a new document with `<<`" do
          @database.stub(:send_request).with("/document?collection=4590", post: { "name" => "The Dude" }).and_return do
            server_response('documents/new-4590-333')
          end
          @database.stub(:send_request).with("/document/4590/333").and_return { server_response('documents/4590-333') }

          # Documents need to get initialized:
          Ashikawa::Core::Document.should_receive(:new)

          subject << {"name" => "The Dude"}
        end
      end

      describe "list all" do
        it "should list all documents" do
          @database.stub(:send_request).with("/simple/all", put: {"collection" => "example_1"}).and_return { server_response('simple-queries/all') }
          @database.should_receive(:send_request).with("/simple/all", put: {"collection" => "example_1"})

          # Documents need to get initialized:
          Ashikawa::Core::Cursor.should_receive(:new)

          subject.all
        end

        it "should limit to a certain amount" do
          @database.stub(:send_request).with("/simple/all", put: {"collection" => "example_1", "limit" => 1}).and_return { server_response('simple-queries/all_skip') }
          @database.should_receive(:send_request).with("/simple/all", put: {"collection" => "example_1", "limit" => 1})

          Ashikawa::Core::Cursor.should_receive(:new)

          subject.all :limit => 1
        end

        it "should skip documents" do
          @database.stub(:send_request).with("/simple/all", put: {"collection" => "example_1", "skip" => 1}).and_return { server_response('simple-queries/all_limit') }
          @database.should_receive(:send_request).with("/simple/all", put: {"collection" => "example_1", "skip" => 1})

          Ashikawa::Core::Cursor.should_receive(:new)

          subject.all :skip => 1
        end
      end

      describe "indices" do
        it "should add a new index" do
          @database.stub(:send_request).with("/index?collection=4590", post: {
            "type" => "hash", "fields" => [ "a", "b" ]
          }).and_return { server_response('indices/new-hash-index') }
          @database.should_receive(:send_request).with("/index?collection=4590", post: {
            "type" => "hash", "fields" => [ "a", "b" ]
          })

          Ashikawa::Core::Index.should_receive(:new).with(subject,
            server_response('indices/new-hash-index'))

          subject.add_index :hash, on: [ :a, :b ]
        end

        it "should get an index by ID" do
          @database.stub(:send_request).with(
            "/index/4590/168054969"
          ).and_return { server_response('indices/hash-index') }

          Ashikawa::Core::Index.should_receive(:new).with(subject,
            server_response('indices/hash-index'))

          subject.index 168054969
        end

        it "should get all indices" do
          @database.stub(:send_request).with(
            "/index?collection=4590"
          ).and_return { server_response('indices/all') }

          Ashikawa::Core::Index.should_receive(:new).exactly(1).times

          indices = subject.indices
          indices.length.should == 1
        end
      end

      describe "by example" do
        before(:each) do
          @example = { :hello => "world" }
        end

        it "should find documents by example" do
          @database.stub(:send_request).with("/simple/by-example", put:
            {"collection" => "example_1", "example" => { :hello => "world"}}
          ).and_return { server_response('simple-queries/example') }
          @database.should_receive(:send_request).with("/simple/by-example", put:
            {"collection" => "example_1", "example" => { :hello => "world"}})

          Ashikawa::Core::Cursor.should_receive(:new)

          subject.by_example example: @example
        end

        it "should find one document by example" do
          @database.stub(:send_request).with("/simple/first-example", put:
            {"collection" => "example_1", "example" => { :hello => "world"}}
          ).and_return { server_response('simple-queries/example') }
          @database.should_receive(:send_request).with("/simple/first-example", put:
            {"collection" => "example_1", "example" => { :hello => "world"}})

          Ashikawa::Core::Document.should_receive(:new)

          subject.first_example @example
        end

        it "should skip documents" do
          @database.stub(:send_request).with("/simple/by-example", put:
            {"collection" => "example_1", "skip" => 1, "example" => { :hello => "world"}}
          ).and_return { server_response('simple-queries/example') }
          @database.should_receive(:send_request).with("/simple/by-example", put:
            {"collection" => "example_1", "skip" => 1, "example" => { :hello => "world"}})

          Ashikawa::Core::Cursor.should_receive(:new)

          subject.by_example example: @example, :skip => 1
        end

        it "should limit documents" do
          @database.stub(:send_request).with("/simple/by-example", put: {"collection" => "example_1", "limit" => 2, "example" => { :hello => "world"}}).and_return { server_response('simple-queries/example') }
          @database.should_receive(:send_request).with("/simple/by-example", put: {"collection" => "example_1", "limit" => 2, "example" => { :hello => "world"}})

          Ashikawa::Core::Cursor.should_receive(:new)

          subject.by_example example: @example, :limit => 2
        end
      end

      describe "near" do
        it "should look for documents based on latitude/longitude" do
          @database.stub(:send_request).with("/simple/near", put: { "collection" => "example_1", "latitude" => 0, "longitude" => 0 }).and_return { server_response('simple-queries/near') }
          @database.should_receive(:send_request).with("/simple/near", put: { "collection" => "example_1", "latitude" => 0, "longitude" => 0 })

          Ashikawa::Core::Cursor.should_receive(:new)

          subject.near :latitude => 0, :longitude => 0
        end
      end

      describe "within" do
        it "should look for documents within a certain radius" do
          @database.stub(:send_request).with("/simple/within", put: { "collection" => "example_1", "latitude" => 0, "longitude" => 0, "radius" => 2 }).and_return { server_response('simple-queries/within') }
          @database.should_receive(:send_request).with("/simple/within" , put: { "collection" => "example_1", "latitude" => 0, "longitude" => 0, "radius" => 2 })

          Ashikawa::Core::Cursor.should_receive(:new)

          subject.within :latitude => 0, :longitude => 0, :radius => 2
        end
      end

      describe "in range" do
        it "should look for documents with an attribute within a certain range" do
          arguments = { "collection" => "example_1", "attribute" => "age", "left" => 50, "right" => 60, "closed" => false}
          @database.stub(:send_request).with("/simple/range", put: arguments).and_return { server_response('simple-queries/range') }
          @database.should_receive(:send_request).with("/simple/range" , put: arguments)

          Ashikawa::Core::Cursor.should_receive(:new)

          subject.in_range attribute: "age", left: 50, right: 60, closed: false
        end
      end
    end
  end
end