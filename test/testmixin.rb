
#
# Testing rufus-treechecker
#
# jmettraux at gmail.org
#
# Fri Aug 29 18:30:03 JST 2008
#

require 'test/unit'
require 'rubygems'
require 'rufus/treechecker'


module TestMixin

  def assert_ok (tc, rubycode)
    tc.check(rubycode)
  end
  def assert_nok (tc, rubycode)
    assert_raise Rufus::SecurityError, tc.stree(rubycode) do
      tc.check(rubycode)
    end
  end
  def assert_nocompile (tc, rubycode)
    assert_raise Racc::ParseError do
      tc.check(rubycode)
    end
  end
end

