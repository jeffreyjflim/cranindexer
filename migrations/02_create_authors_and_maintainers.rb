Sequel.migration do
	change do
		create_table(:authors) do
			String :name, primary_key: true
			String :email
		end

		create_table(:maintainers) do
			String :name, primary_key: true
			String :email
		end
	end
end
