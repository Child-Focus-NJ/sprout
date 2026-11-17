# .simplecov
require 'simplecov-cobertura'

SimpleCov.root File.expand_path(__dir__)

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::CoberturaFormatter
])

