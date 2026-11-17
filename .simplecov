# .simplecov
require 'simplecov-cobertura'

SimpleCov.root File.expand_path(__dir__)

SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::CoberturaFormatter
])
