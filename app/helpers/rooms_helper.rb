module RoomsHelper
  def short_time_ago(time)
    return "" unless time
    diff = Time.current - time
    if diff < 1.minute
      "Just now"
    elsif diff < 1.hour
      "#{ (diff / 1.minute).to_i }m ago"
    elsif diff < 1.day
      "#{ (diff / 1.hour).to_i }h ago"
    elsif diff < 1.week
      "#{ (diff / 1.day).to_i }d ago"
    else
      "#{ (diff / 1.week).to_i }w ago"
    end
  end
  def room_gradient_class(room, index)
    gradients = [
      "from-amber-400 to-orange-500 shadow-orange-100",
      "from-orange-400 to-red-500 shadow-red-100",
      "from-slate-400 to-slate-600 shadow-slate-200",
      "from-sky-400 to-indigo-500 shadow-sky-100",
      "from-yellow-400 to-amber-600 shadow-amber-100",
      "from-pink-300 to-rose-400 shadow-rose-100",
      "from-purple-300 to-pink-500 shadow-purple-100"
    ]
    gradients[index % gradients.length]
  end
end
