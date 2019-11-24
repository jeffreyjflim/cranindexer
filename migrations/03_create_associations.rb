Sequel.migration do
	change do
		create_table(:authors_packages) do
			String :author_name, null: false
			String :package_name, null: false
			String :package_version, null: false
		end
	end
end
