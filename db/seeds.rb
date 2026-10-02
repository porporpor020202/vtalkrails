# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
seed_patterns = [Rails.root.join("db/seeds/*.rb")]
seed_patterns << Rails.root.join("db/seeds/development/*.rb") if Rails.env.development?

seed_patterns.each do |pattern|
  Dir[pattern].sort.each do |file|
    puts "Seeding: #{Pathname.new(file).relative_path_from(Rails.root)}"
    load file
  end
end
