require './index'

describe CRANIndexer do

	before(:each) do
		@indexer = CRANIndexer.new
		@test_server = 'http://localhost:9000'
	end

	it 'indexes and records all packages when the database is new' do
		@indexer.clear_db

		@indexer.call "#{@test_server}/PACKAGES"

		# !! NOTE Dcf raises '#<ArgumentError: invalid byte sequence in UTF-8>' with BACprior_2.0.tar.gz because of the 'Author' field value;
		# !! according to https://www.debian.org/doc/debian-policy/ch-controlfields.html, 'All control files must be encoded in UTF-8.'
		expect(Package.count).to eq 10
		expect(Maintainer.count).to eq 8
	end

	it 'associates packages <-> maintainers correctly, including in the case when multiple packages have the same maintainer' do
		package_abc = Package.first(name: 'abc')
		blum_michael = Maintainer['Blum Michael']

		expect(package_abc.maintainer).to eq(blum_michael)
		expect(blum_michael.packages.count).to eq 1
		expect(blum_michael.packages.first).to eq package_abc

		henrik_singmann = Maintainer[name: 'Henrik Singmann']
		expect(henrik_singmann.packages.count).to eq 3
		[["acss", "0.2-5"], ["acss.data", "1.0"], ["afex", "0.25-1"]].each do |package|
			expect(Package.send('[]', package).maintainer).to eq henrik_singmann
		end
	end

	it 'indexes any new packages whenever it is rerun' do
		@indexer.call "#{@test_server}/PACKAGES_2"

		expect(Package.count).to eq 13
		expect(Maintainer.count).to eq 10
	end

	it 'associates packages <-> maintainers correctly for new packages' do
		abc_packages = Package.where(name: 'abc')
		abc2_1_maintainer = Package[name: 'abc', version: '2.1'].maintainer

		expect(abc_packages.count).to eq 2
		expect(abc_packages.map(&:version)).to match_array ['2.1', '2.2']
		expect(abc_packages.map(&:maintainer)).to match_array [abc2_1_maintainer, abc2_1_maintainer]
	end

end
