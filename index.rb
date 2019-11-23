require 'bundler/setup'

require 'open-uri'

require 'sequel'

COMMAND_LINE = $0 == 'index.rb' ? true : false

# !! Using a class isn't strictly necessary; but it makes it easier to test with RSpec (you can instantiate an instance and call a method)
class CRANIndexer
	def call(package_path='https://cran.r-project.org/src/contrib/PACKAGES')
		puts "Grabbing package list from #{package_path}"

		open(package_path) do |f|
			f.each_line {|line|
				puts line
				if line.strip.empty?
					# do processing
					puts '=========='
				end
			}
		end
	end
end

if COMMAND_LINE
	ARGV[0] ? CRANIndexer.new.call(ARGV[0]) : CRANIndexer.new.call
end
