
#
# Specifying rufus-treechecker
#
# Wed Dec 22 16:58:11 JST 2010
#

require File.join(File.dirname(__FILE__), 'spec_base')


describe Rufus::TreeChecker do

  describe '.parse' do

    it 'returns the AST as an array' do

      Rufus::TreeChecker.parse('1 + 1').should ==
        [ :call, [ :lit, 1 ], :+, [ :arglist, [ :lit, 1 ] ] ]
    end
  end

  describe '.clone' do

    it "returns a copy of the TreeChecker" do

      tc0 = Rufus::TreeChecker.new do
        exclude_fvccall :abort
      end

      tc1 = tc0.clone

      class << tc0
        attr_reader :set, :root_set
      end
      class << tc1
        attr_reader :set, :root_set
      end

      tc1.set.object_id.should_not == tc0.set.object_id
      tc1.root_set.object_id.should_not == tc0.root_set.object_id

      tc1.set.should == tc0.set
      tc1.root_set.should == tc0.root_set
    end

    it "sets @current_set correclty when cloning" do

      tc0 = Rufus::TreeChecker.new

      tc1 = tc0.clone

      tc1.add_rules do
        exclude_def
      end

      class << tc0
        attr_reader :set, :root_set
      end
      class << tc1
        attr_reader :set, :root_set
      end

      tc0.set.excluded_symbols.keys.should_not include(:defn)
      tc1.set.excluded_symbols.keys.should include(:defn)
    end
  end
end

