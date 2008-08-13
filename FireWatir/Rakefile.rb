require 'rubygems'
require 'pathname'

__DIR__ = Pathname.new(__FILE__).dirname

namespace :gem do

  task :build do
    load __DIR__ + "firewatir.gemspec"
    Gem::Builder.new(@firewatir_spec).build
  end

  task :install => :build do
    cmd = "gem install firewatir -l"
    system cmd unless system "sudo #{cmd}"
  end

  task :clean_install => :install do
    FileUtils.rm(__DIR__ + "firewatir-#{@firewatir_spec.version}.gem")
  end
end

task :cleanup do 
  Dir.glob("**/*.*~")+Dir.glob("**/*~").each{|swap|FileUtils.rm(swap, :force => true)}
end