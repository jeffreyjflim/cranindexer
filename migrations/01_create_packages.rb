Sequel.migration do
	change do
		create_table(:packages) do
			primary_key :id

			String :name
			String :version
			DateTime :date_publication

			String :title
			String :description
		end
	end
end
