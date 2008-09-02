
#
# Testing rufus-treechecker
#
# jmettraux at gmail.org
#
# Tue Sep  2 14:28:01 JST 2008
#

require 'testmixin'

class CloneTest < Test::Unit::TestCase
  include TestMixin


  def test_0

    tc0 = Rufus::TreeChecker.new do
      exclude_fvccall :abort
    end

    tc1 = tc0.clone
    tc1.add_rules do
      at_root do
        exclude_head [ :block ]
      end
    end

    assert_not_equal tc0.object_id, tc1.object_id
  end
end

