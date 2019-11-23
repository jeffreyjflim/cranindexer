require 'bundler/setup'

require 'open-uri'
require 'fileutils'
require 'tempfile'

require 'dcf'

require 'sequel'


COMMAND_LINE = $0 == 'index.rb' ? true : false

# !! Using a class isn't strictly necessary; but it makes it easier to test with RSpec (you can instantiate an instance and call a method)
class CRANIndexer

	attr_accessor :package_dir

	def call(package_path='https://cran.r-project.org/src/contrib/PACKAGES')
		puts "Grabbing package list from #{package_path}"
		@package_dir = package_path.sub(/PACKAGES$/, '')

		package_count = 0
		open(package_path) do |f|
			lines = ''
			f.each_line {|line|
				if line.strip.empty?
					# do processing
					package_count += 1
					parse lines

					lines = ''
				else
					lines += line
				end

				break if package_count == 10
			}

			parse lines if lines != ''	# !! the last package may not have an empty line after it!
		end
	end

	private
	def parse(lines)

		FileUtils.mkdir_p('tmp')

		transforms = {
			'Package'          => 'name',
			'Version'          => 'version',
			'Date/Publication' => 'date_publication',
			'Title'            => 'title',
			'Description'      => 'description',
		}

		attribs = (Dcf.parse lines)[0]

		# code from https://stackoverflow.com/questions/2263540/how-do-i-download-a-binary-file-over-http, 'Overbyrd's answer
		download_path = "tmp/#{attribs['Package']}_#{attribs['Version']}.tar.gz"
		case io = open("#{@package_dir}#{attribs['Package']}_#{attribs['Version']}.tar.gz")
			when StringIO
				File.open(download_path, 'w') { |f| f.write(io) }
			when Tempfile
				io.close
				FileUtils.mv(io.path, download_path)
		end

		desc_string = `tar -Oxf #{download_path} #{attribs['Package']}/DESCRIPTION`
		lines += desc_string
		attribs = (Dcf.parse desc_string)[0]
p attribs
		data_hash = {}
		transforms.each do |transform|
			data_hash[transform[1]] = attribs[transform[0]]
		end
p data_hash
STDIN.gets
	end
end

if COMMAND_LINE
	ARGV[0] ? CRANIndexer.new.call(ARGV[0]) : CRANIndexer.new.call
end
