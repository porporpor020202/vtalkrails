module UserDisplayNameGenerator
  # Two different descriptors plus an animal give us more than one million
  # readable names while keeping the animal emoji stable for each user.
  ADJECTIVES = %w[
    Adventurous Agile Amber Ancient Artful Astonishing Audacious Autumn Azure
    Balanced Bashful Bold Bouncy Brave Bright Brilliant Calm Caring Cheerful Clever
    Cloudy Cozy Curious Daring Dazzling Diligent Dreamy Eager Elegant Enchanted
    Energetic Fair Fearless Festive Fierce Fluffy Fortunate Friendly Gentle
    Glimmering Gleaming Graceful Grateful Happy Harmonious Heroic Honest Hopeful
    Humble Jolly Joyful Kind Lively Lucky Luminous Magical Merry Mighty Mindful
    Misty Modest Noble Optimistic Peaceful Playful Pleasant Polite Powerful Pristine
    Proud Quick Quiet Radiant Ready Regal Relaxed Remarkable Resilient Respectful
    Roaring Rosy Royal Sassy Serene Shimmering Shiny Silky Sincere Skillful Sleepy
    Smart Snappy Sociable Soft Sparkling Spirited Splendid Steady Sunny Swift
    Tender Thoughtful Tiny Tranquil Trusty Valiant Vibrant Victorious Warm Whimsical
    Wise Witty Wonderful Zany Zealous Zesty Abundant Breezy Brisk Charming Colorful
    Dapper Dewy Dynamic Enthusiastic Glorious Inspiring Inventive Lively Loyal Mellow
    Mysterious Nimble Plucky Quirky Rejoicing Shy Sleek Spunky Starlit Upbeat
    Vivacious Wandering Watchful Welcoming Whistling Youthful
  ].freeze

  ANIMALS = [
    [ "Raccoon", "🦝" ], [ "Tiger", "🐯" ], [ "Fox", "🦊" ], [ "Panda", "🐼" ],
    [ "Cat", "🐱" ], [ "Koala", "🐨" ], [ "Rabbit", "🐰" ], [ "Lion", "🦁" ],
    [ "Dog", "🐶" ], [ "Bear", "🐻" ], [ "Polar Bear", "🐻‍❄️" ], [ "Wolf", "🐺" ],
    [ "Leopard", "🐆" ], [ "Deer", "🦌" ], [ "Horse", "🐴" ], [ "Zebra", "🦓" ],
    [ "Giraffe", "🦒" ], [ "Elephant", "🐘" ], [ "Mammoth", "🦣" ], [ "Rhino", "🦏" ],
    [ "Hippo", "🦛" ], [ "Cow", "🐮" ], [ "Pig", "🐷" ], [ "Goat", "🐐" ],
    [ "Sheep", "🐑" ], [ "Monkey", "🐒" ], [ "Gorilla", "🦍" ], [ "Orangutan", "🦧" ],
    [ "Sloth", "🦥" ], [ "Otter", "🦦" ], [ "Beaver", "🦫" ], [ "Mouse", "🐭" ],
    [ "Hamster", "🐹" ], [ "Hedgehog", "🦔" ], [ "Bat", "🦇" ], [ "Owl", "🦉" ],
    [ "Eagle", "🦅" ], [ "Parrot", "🦜" ], [ "Penguin", "🐧" ], [ "Flamingo", "🦩" ],
    [ "Swan", "🦢" ], [ "Duck", "🦆" ], [ "Chicken", "🐔" ], [ "Rooster", "🐓" ],
    [ "Turkey", "🦃" ], [ "Peacock", "🦚" ], [ "Fish", "🐟" ], [ "Dolphin", "🐬" ],
    [ "Whale", "🐋" ], [ "Shark", "🦈" ], [ "Octopus", "🐙" ], [ "Crab", "🦀" ],
    [ "Lobster", "🦞" ], [ "Shrimp", "🦐" ], [ "Turtle", "🐢" ], [ "Crocodile", "🐊" ],
    [ "Snake", "🐍" ], [ "Lizard", "🦎" ], [ "Frog", "🐸" ], [ "Butterfly", "🦋" ],
    [ "Bee", "🐝" ], [ "Ladybug", "🐞" ], [ "Ant", "🐜" ], [ "Snail", "🐌" ],
    [ "Spider", "🕷️" ]
  ].freeze

  Identity = Struct.new(:name, :icon, :animal_key, keyword_init: true)

  class << self
    def for_id(id)
      ordinal = [ id.to_i - 1, 0 ].max
      pair_count = ADJECTIVES.length * (ADJECTIVES.length - 1)
      cycle, remainder = ordinal.divmod(pair_count * ANIMALS.length)
      pair_index, animal_index = remainder.divmod(ANIMALS.length)
      first_index, second_offset = pair_index.divmod(ADJECTIVES.length - 1)
      second_index = second_offset >= first_index ? second_offset + 1 : second_offset
      animal_name, icon = ANIMALS.fetch(animal_index)

      base_name = "#{ADJECTIVES.fetch(first_index)} #{ADJECTIVES.fetch(second_index)} #{animal_name}"
      name = cycle.zero? ? base_name : "#{base_name} #{cycle + 1}"
      Identity.new(name:, icon:, animal_key: animal_name.parameterize)
    end

    def capacity
      ADJECTIVES.length * (ADJECTIVES.length - 1) * ANIMALS.length
    end
  end
end
