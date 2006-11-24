# these are the tests that run reliably and invisibly

TOPDIR = File.join(File.dirname(__FILE__), '..')
$LOAD_PATH.unshift TOPDIR

require 'unittests/setup.rb'

Dir.chdir TOPDIR

tests = ["unittests/javascript_test.rb",
         "unittests/links_xpath_test.rb"
        ]

tests.each { |x| require x }
$core_tests.each {|x| require x unless x =~ /xpath/}

#$HIDE_IE = true
#$ff.visible = false

