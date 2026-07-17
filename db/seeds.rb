# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create main user if not exists
me = User.find_or_initialize_by(email_address: "me@example.com")
me.name = "Me"
me.icon = "👤"
me.password = "password" if me.new_record?
me.save!

opponents_data = [
  { name: "Raccoon", icon: "🦝", status: :your_turn, updated_at: 2.minutes.ago },
  { name: "Lion", icon: "🦁", status: :deleted, updated_at: 5.days.ago },
  { name: "Fox", icon: "🦊", status: :waiting, updated_at: 45.minutes.ago },
  { name: "Panda", icon: "🐼", status: :your_turn, updated_at: 4.hours.ago },
  { name: "Cat", icon: "🐱", status: :deleted, updated_at: 1.week.ago },
  { name: "Koala", icon: "🐨", status: :waiting, updated_at: 2.hours.ago },
  { name: "Tiger", icon: "🐯", status: :your_turn, updated_at: 1.day.ago },
  { name: "Rabbit", icon: "🐰", status: :waiting, updated_at: 3.days.ago }
]

opponents_data.each do |data|
  # Create opponent user
  email = "#{data[:name].downcase}@example.com"
  opponent = User.find_or_initialize_by(email_address: email)
  opponent.name = data[:name]
  opponent.icon = data[:icon]
  opponent.password = "password" if opponent.new_record?
  opponent.save!

  # Find or create room
  room = Room.find_or_initialize_by(user: me, opponent: opponent)
  room.status = data[:status]
  room.updated_at = data[:updated_at]
  room.save!
end
