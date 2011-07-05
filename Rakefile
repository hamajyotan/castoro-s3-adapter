
require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rake/gempackagetask'
require 'rake/rdoctask'

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'castoro-s3-adapter/version'

Gem::Specification.new do |s|
  s.name = 'castoro-s3-adapter'
  s.version = Castoro::S3Adapter::Version::STRING
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.textile']
  s.summary = "This(it) is (storage) adapter for Castoro which is distributed abstraction filesystem."
  s.description = s.summary
  s.executables = Dir.glob("bin/**/*").map { |f| File.basename(f) }
  s.files = %w(History.txt LICENSE README.textile Rakefile) + Dir.glob("{bin,setup,lib,resources,spec,config}/**/*")
  s.require_path = "lib"
  s.bindir = "bin"
  s.authors = ["castoro project"]

  s.add_dependency('castoro-client', '>= 0.1.0')
  s.add_dependency('sinatra')
  s.add_dependency('builder')

  s.add_development_dependency('aws-s3')

  Rake::GemPackageTask.new(s) do |p|
    p.gem_spec = s
    p.need_tar = true
    p.need_zip = true
  end
end

Rake::RDocTask.new do |rdoc|
  files =['README.textile', 'LICENSE', 'lib/**/*.rb']
  rdoc.rdoc_files.add(files)
  rdoc.main = "README.textile" # page to start on
  rdoc.title = "castor-s3-adapter Docs"
  rdoc.rdoc_dir = 'doc/rdoc' # rdoc output folder
  rdoc.options << '--line-numbers'
end

Dir['tasks/**/*.rake'].each { |t| load t }

task :default => [:spec]

