class Package < Sequel::Model
	many_to_many :authors, left_key: [:package_name, :package_version], right_key: :author_name
	many_to_one :maintainer, key: :maintainer_name
end

class Author < Sequel::Model
	many_to_many :packages, left_key: :author_name, right_key: [:package_name, :package_version]
end

class Maintainer < Sequel::Model
	one_to_many :packages, key: :maintainer_name
end
