
#
# Testing rufus-treechecker
#
# jmettraux at gmail.org
#
# Fri Aug 29 10:13:33 JST 2008
#

require 'testmixin'


class BasicTest < Test::Unit::TestCase
  include TestMixin


  def test_0

    tc = Rufus::TreeChecker.new do
      exclude_vcall :abort
      exclude_fcall :abort
      exclude_call_to :abort
      exclude_fvcall :exit, :exit!
      exclude_call_to :exit
      exclude_call_to :exit!
    end

    assert_nok(tc, 'exit')
    assert_nok(tc, 'exit()')
    assert_nok(tc, 'exit!')
    assert_nok(tc, 'abort')
    assert_nok(tc, 'abort()')
    assert_nok(tc, 'Kernel.exit')
    assert_nok(tc, 'Kernel.exit()')
    assert_nok(tc, 'Kernel::exit')
    assert_nok(tc, 'Kernel::exit()')
    assert_nok(tc, '::Kernel.exit')

    assert_ok(tc, '1 + 1')
  end

  def test_0b_vm_exiting

    # TODO : implement me !
  end

  def test_1_global_vars

    tc = Rufus::TreeChecker.new do
      exclude_global_vars
    end

    assert_nok(tc, '$ENV')
    assert_nok(tc, '$ENV = {}')
    assert_nok(tc, "$ENV['HOME'] = 'away'")
  end

  def test_2_aliases

    tc = Rufus::TreeChecker.new do
      exclude_alias
    end

    assert_nok(tc, 'alias :a :b')
  end

  def test_3_exclude_calls_on

    tc = Rufus::TreeChecker.new do
      exclude_call_on File, FileUtils
      exclude_call_on IO
    end
    #puts tc.to_s

    assert_nok(tc, 'data = File.read("surf.txt")')
    assert_nok(tc, 'f = File.new("surf.txt")')
    assert_nok(tc, 'FileUtils.rm_f("bondzoi.txt")')
    assert_nok(tc, 'IO.foreach("testfile") {|x| print "GOT ", x }')
  end

  def test_4_exclude_def

    tc = Rufus::TreeChecker.new do
      exclude_def
    end

    assert_nok(tc, 'def drink; "water"; end')
    assert_nok(tc, 'class Toto; def drink; "water"; end; end')
  end

  def test_5_exclude_class_tinkering

    tc = Rufus::TreeChecker.new do
      exclude_class_tinkering
    end

    assert_nok(tc, 'class << instance; def length; 3; end; end')
    assert_nok(tc, 'class Toto; end')
    assert_nok(tc, 'class Alpha::Toto; end')
  end

  def test_5b_exclude_class_tinkering_with_exceptions

    tc = Rufus::TreeChecker.new do
      exclude_class_tinkering :except => [ String, Rufus::TreeChecker ]
    end
    #puts tc.to_s

    assert_nok(tc, 'class String; def length; 3; end; end')

    assert_ok(tc, 'class S2 < String; def length; 3; end; end')
    assert_ok(tc, 'class Toto < Rufus::TreeChecker; def length; 3; end; end')

    assert_nok(tc, 'class Toto; end')
    assert_nok(tc, 'class Alpha::Toto; end')
  end

  def test_6_exclude_module_tinkering

    tc = Rufus::TreeChecker.new do
      exclude_module_tinkering
    end

    assert_nok(tc, 'module Alpha; end')
    assert_nok(tc, 'module Momo::Alpha; end')
  end

  def test_7_exclude_eval

    tc = Rufus::TreeChecker.new do
      exclude_eval
    end

    assert_nok(tc, 'eval("code")')
    assert_nok(tc, 'Kernel.eval("code")')
    assert_nok(tc, 'toto.instance_eval("code")')
    assert_nok(tc, 'Toto.module_eval("code")')
  end

  def test_8_exclude_backquotes

    tc = Rufus::TreeChecker.new do
      exclude_backquotes
    end

    assert_nok(tc, '`kill -9 whatever`')
  end

  def test_9_exclude_raise_and_throw

    tc = Rufus::TreeChecker.new do
      exclude_raise
    end

    assert_nok(tc, 'raise')
    assert_nok(tc, 'raise "error"')
    assert_nok(tc, 'Kernel.raise')
    assert_nok(tc, 'Kernel.raise "error"')
    assert_ok(tc, 'Kernel.puts "error"')
    assert_nok(tc, 'throw')
    assert_nok(tc, 'throw :halt')
  end

  def test_10_exclude_public

    tc = Rufus::TreeChecker.new do
      exclude_fvccall :public
      exclude_fvccall :protected
      exclude_fvccall :private
    end

    assert_nok(tc, 'public')
    assert_nok(tc, 'public :surf')
    assert_nok(tc, 'class Toto; public :car; end')
    assert_nok(tc, 'private')
    assert_nok(tc, 'private :surf')
    assert_nok(tc, 'class Toto; private :car; end')
  end

  def test_11_is_not

    tc = Rufus::TreeChecker.new do
      exclude_head [ :block ]
      exclude_head [ :lasgn ]
      exclude_head [ :dasgn_curr ]
    end

    assert_nok(tc, 'a; b; c')
    assert_nok(tc, 'lambda { a; b; c }')

    assert_nok(tc, 'a = 2')
    assert_nok(tc, 'lambda { a = 2 }')
  end

  def test_12_at_root

    tc = Rufus::TreeChecker.new do
      at_root do
        exclude_head [ :block ]
        exclude_head [ :lasgn ]
      end
    end

    assert_nok(tc, 'a; b; c')
    assert_ok(tc, 'lambda { a; b; c }')

    assert_nok(tc, 'a = 2')
    assert_ok(tc, 'lambda { a = 2 }')
  end

  def test_12_rebinding

    tc = Rufus::TreeChecker.new do
      exclude_call_to :class
      exclude_rebinding Kernel, Rufus::TreeChecker
    end

    assert_nok(tc, 'k = Kernel')
    assert_nok(tc, 'k = ::Kernel')
    assert_nok(tc, 'c = Rufus::TreeChecker')
    assert_nok(tc, 'c = ::Rufus::TreeChecker')
    assert_nok(tc, 's = "".class')
  end

  def test_13_access_to

    tc = Rufus::TreeChecker.new do
      exclude_access_to File
    end

    #puts tc.to_s

    assert_nok(tc, 'f = File')
    assert_nok(tc, 'f = ::File')
    assert_nok(tc, 'File.read "hello.txt"')
    assert_nok(tc, '::File.read "hello.txt"')
  end

  #def test_X
  #  tc = Rufus::TreeChecker.new do
  #  end
  #  #tc.ptree 'load "surf"'
  #  tc.ptree 'class Toto; load "nada"; end'
  #  tc.ptree 'class Toto; def m; load "nada"; end; end'
  #  tc.ptree 'class << toto; def m; load "nada"; end; end'
  #  #tc.ptree 'lambda { a; b; c }'
  #  #tc.ptree 'lambda { a = c }'
  #  #tc.ptree 'c = 0; a = c'
  #  #tc.ptree 'c = a = 0'
  #  tc.ptree 'a = 5 + 6; puts a'
  #end
end

