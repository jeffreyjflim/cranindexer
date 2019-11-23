Sequel.migration do
	change do
		create_table(:packages) do
			String :name
			String :version
			primary_key [:name, :version]

			DateTime :date_publication

			String :title
			String :description
		end
	end
end
