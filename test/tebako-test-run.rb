# frozen_string_literal: true

puts "Hello!"
puts "Gem path: #{Gem.path}"
puts "Rubygems version: #{Gem::rubygems_version}"
if defined?(TebakoRuntime::VERSION)
  puts "Using tebako-runtime v#{TebakoRuntime::VERSION}"
else
  puts "Tebako runtime not loaded"
end