# -*- ruby -*-

guard 'rspec', cmd: 'bundle exec rspec' do
  directories %w(lib spec)
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch(%r{^(spec/(.*)spec\.rb$)})        { |m| m[1] }
  watch(%r{^spec/(.*)spec_helper.rb$})    { "spec" }
end

