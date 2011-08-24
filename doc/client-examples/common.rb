
require 'erb'
require 'yaml'

$config = YAML.load(ERB.new(IO.read(File.expand_path('../config.yml', __FILE__))).result)

module Kernel
  def puts *args
    $stderr.puts *args
  end
end

require 'optparse'

def command_line
  OptionParser.new { |opt|
    opt.summary_width = 48
    yield opt
  }
end

