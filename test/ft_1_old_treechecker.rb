
#
# Testing rufus-treechecker
#
# jmettraux at gmail.org
#
# Fri Aug 29 10:13:33 JST 2008
#

require 'testmixin'

module Testy
  class Tasty
  end
end

class OldTreeCheckerTest < Test::Unit::TestCase
  include TestMixin


  def test_0

    tc = Rufus::TreeChecker.new do
      exclude_fvccall :abort
      exclude_fvccall :exit, :exit!
      exclude_fvccall :system
      exclude_eval
      exclude_alias
      exclude_global_vars
      exclude_call_on File, FileUtils
      exclude_class_tinkering :except => Testy::Tasty
      exclude_module_tinkering

      exclude_fvcall :public
      exclude_fvcall :protected
      exclude_fvcall :private
      exclude_fcall :load
      exclude_fcall :require
    end

    assert_nocompile tc, "def surf }"

    assert_ok tc, "puts 'toto'"

    assert_nok tc, "exit"
    assert_nok tc, "puts $BATEAU"
    assert_nok tc, "abort"
    assert_nok tc, "abort; puts 'ok'"
    assert_nok tc, "puts 'ok'; abort"

    assert_nok tc, "exit 0"
    assert_nok tc, "system('whatever')"

    assert_nok tc, "alias :a :b"
    assert_nok tc, "alias_method :a, :b"

    assert_nok tc, "File.open('x')"
    assert_nok tc, "FileUtils.rm('x')"

    assert_nok tc, "eval 'nada'"
    assert_nok tc, "M.module_eval 'nada'"
    assert_nok tc, "o.instance_eval 'nada'"

    assert_ok tc, "puts 'toto'"

    assert_ok tc, "class Toto < Testy::Tasty\nend"
    assert_nok tc, "class String\nend"
    assert_nok tc, "module Whatever\nend"
    assert_nok tc, "class << e\nend"
  end
end

