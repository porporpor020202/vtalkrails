class RoomsController < ApplicationController
  def index
    # A simple mock list of rooms for now
    @rooms = [
      { id: 1, name: "General Chat" },
      { id: 2, name: "Random" },
      { id: 3, name: "Rails & Hotwire" }
    ]
  end
end
