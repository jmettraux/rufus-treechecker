#
#--
# Copyright (c) 2008, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#++
#

#
# "made in Japan" (as opposed to "swiss made")
#

require 'ruby_parser' # gem 'rogue_parser'


module Rufus

  #
  # Instances of this error class are thrown when the ruby code being
  # checked contains exclude stuff
  #
  class SecurityError < RuntimeError
  end

  #
  # TreeChecker relies on ruby_parser to turns a piece of ruby code (a string)
  # into a bunch of sexpression and then TreeChecker will check that
  # sexpression tree and raise a Rufus::SecurityException if an excluded
  # pattern is spotted.
  #
  # The TreeChecker is meant to be useful for people writing DSLs directly
  # in Ruby (not via their own parser) that want to check and prevent
  # bad things from happening in this code.
  #
  #   tc = Rufus::TreeChecker.new do
  #     exclude_method :abort
  #     exclude_methods :exit, :exit!
  #   end
  #
  #   tc.check("1 + 1; abort")               # will raise a SecurityError
  #   tc.check("puts (1..10).to_a.inspect")  # OK
  #
  # == featured exclusion methods
  #
  # - exclude_symbol
  # - exclude_fcall
  # - exclude_vcall
  # - exclude_call_on
  # - exclude_call_to
  # - exclude_def
  # - exclude_class_tinkering
  # - exclude_module_tinkering
  #
  # - exclude_eval
  # - exclude_global_vars
  # - exclude_alias
  # - exclude_vm_exiting
  # - exclude_raise
  #
  class TreeChecker

    VERSION = '1.0'

    def initialize (&block)

      raise "new() expects a block with some exclusion rules" unless block

      @checks = []

      instance_eval(&block)
    end

    def check (rubycode)

      do_check(parse(rubycode))
    end

    protected

    #
    # the methods used to define the checks

    [
      :exclude_symbol,
      :exclude_fcall,
      :exclude_vcall,
      :exclude_call_on,
      :exclude_call_to
    ].each do |m|
      class_eval <<-EOS
        def #{m} (*args)
          message = args.last.is_a?(String) ? args.pop : nil
          args.each { |a| @checks << [ :do_#{m}, a.to_sym, message ] }
        end
      EOS
    end

    #
    # bans method definitions
    #
    def exclude_def
      @checks << [
        :do_exclude_symbol, :defn, "method definitions are forbidden" ]
    end

    #
    # bans the defintion and the [re]openening of classes
    #
    # a list of exceptions (classes) can be passed. Subclassing those
    # exceptions is permitted.
    #
    def exclude_class_tinkering (*exceptions)
      @checks << [
        :do_exclude_class_tinkering ] + exceptions.collect { |e| parse(e.to_s) }
      @checks << [
        :do_exclude_symbol, :sclass, "defining or opening a class is forbidden"
      ]
    end

    #
    # bans the definition or the opening of modules
    #
    def exclude_module_tinkering
      @checks << [
        :do_exclude_symbol, :module, "defining or opening a module is forbidden"
      ]
    end

    #
    # bans referencing or setting the value of global variables
    #
    def exclude_global_vars
      @checks << [ :do_exclude_symbol, :gvar, "global vars are forbidden" ]
      @checks << [ :do_exclude_symbol, :gasgn, "global vars are forbidden" ]
    end

    #
    # bans the usage of 'alias'
    #
    def exclude_alias
      @checks << [ :do_exclude_symbol, :alias, "'alias' is forbidden" ]
    end

    #
    # bans the use of 'eval', 'module_eval' and 'instance_eval'
    #
    def exclude_eval
      @checks << [
        :do_exclude_fcall,
        :eval,
        "eval() is forbidden" ]
      @checks << [
        :do_exclude_call_to,
        :instance_eval,
        "instance_eval() is forbidden" ]
      @checks << [
        :do_exclude_call_to,
        :module_eval,
        "module_eval() is forbidden" ]
    end

    #
    # bans the use of backquotes
    #
    def exclude_backquotes
      @checks << [ :do_exclude_symbol, :xstr, "backquotes are forbidden" ]
    end

    #
    # the actual check method, check() is rather a bootstrap one...
    #
    def do_check (sexp)

      @checks.each do |exclusion_method, *args|
        send exclusion_method, sexp, args
      end

      return unless sexp.is_a?(Array) # check over, seems fine...

      # check children

      sexp.each { |c| do_check c }
    end

    #
    # the methods that actually perform the checks
    # (and potentially raise security exceptions)

    def do_exclude_fcall (sexp, args)

      return unless sexp.is_a?(Array) # lonely symbols are not function calls

      excluded_function_name = args.first
      head = sexp[0, 2]

      raise SecurityError.new(
        "fcall to '#{excluded_function_name}' is forbidden"
      ) if head == [ :fcall, excluded_function_name ]
    end

    def do_exclude_vcall (sexp, args)

      return unless sexp.is_a?(Array) # lonely symbols are vcalls

      excluded_function_name = args.first
      head = sexp[0, 2]

      raise SecurityError.new(
        "vcall to '#{excluded_function_name}' is forbidden"
      ) if head == [ :vcall, excluded_function_name ]
    end

    #
    # raises a Rufus::SecurityError if the sexp is a reference to
    # a certain symbol (like :gvar or :alias).
    #
    def do_exclude_symbol (sexp, args)

      raise SecurityError.new(
        args[1] || "symbol :#{excluded_symbol} is forbidden"
      ) if sexp == args[0]
    end

    def do_exclude_class_tinkering (sexp, args)

      return unless sexp.is_a?(Array) # lonely symbols are not class definitions

      return unless sexp.first == :class

      raise SecurityError.new(
        'class definition or opening forbidden'
      ) if args.length == 0 or ( ! args.include?(sexp[2]))
        #
        # raise error if there are no exceptions or
        # if the parent class is not a member of the exception list
    end

    #
    # raises a security error if the sexp is a call on a given constant or
    # module (class)
    #
    def do_exclude_call_on (sexp, args)

      return unless sexp.is_a?(Array) # lonely symbols are not method calls

      excluded = args.first
      head = sexp[0, 2]

      raise SecurityError.new(
        "calls on #{excluded} are forbidden"
      ) if head == [ :call, [ :const, excluded ] ]
    end

    #
    # raises a security error if a call to a given method of any instance
    # is found
    #
    def do_exclude_call_to (sexp, args)

      return unless sexp.is_a?(Array)

      raise SecurityError.new(
        "call to '#{args[0]}' is forbidden"
      ) if sexp[0] == :call and sexp[2] == args[0]
    end

    #
    # a simple parse (relies on ruby_parser currently)
    #
    def parse (rubycode)

      RubyParser.new.parse(rubycode).to_a
    end
  end
end
