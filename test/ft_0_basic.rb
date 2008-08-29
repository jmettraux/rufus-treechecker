
#
# Testing rufus-treechecker
#
# jmettraux at gmail.org
#
# Fri Aug 29 10:13:33 JST 2008
#

require 'test/unit'

require 'rubygems'

require 'rufus/treechecker'



class BasicTest < Test::Unit::TestCase

  def test_0

    tc = Rufus::TreeChecker.new do
      exclude_method :abort
      exclude_methods :exit, :exit!
    end

    assert_raise Rufus::SecurityError do
      tc.check('exit')
    end
    assert_raise Rufus::SecurityError do
      tc.check('exit!')
    end
    assert_raise Rufus::SecurityError do
      tc.check('abort')
    end
    tc.check('1 + 1')
  end

  def test_1_global_vars

    tc = Rufus::TreeChecker.new do
      exclude_global_vars
    end

    assert_raise Rufus::SecurityError do
      tc.check('$ENV')
    end
    assert_raise Rufus::SecurityError do
      tc.check('$ENV = {}')
    end
    assert_raise Rufus::SecurityError do
      tc.check("$ENV['HOME'] = 'away'")
    end
  end

  def test_2_aliases

    tc = Rufus::TreeChecker.new do
      exclude_alias
    end

    assert_raise Rufus::SecurityError do
      tc.check('alias :a :b')
    end
  end

  def test_3_exclude_calls_on

    tc = Rufus::TreeChecker.new do
      exclude_calls_on :File, :FileUtils
      exclude_calls_on :IO
    end

    assert_raise Rufus::SecurityError do
      tc.check('data = File.read("surf.txt")')
    end
    assert_raise Rufus::SecurityError do
      tc.check('f = File.new("surf.txt")')
    end
    assert_raise Rufus::SecurityError do
      tc.check('FileUtils.rm_f("bondzoi.txt")')
    end
    assert_raise Rufus::SecurityError do
      tc.check('IO.foreach("testfile") {|x| print "GOT ", x }')
    end
  end
end

