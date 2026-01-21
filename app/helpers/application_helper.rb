module ApplicationHelper
  # Returns a background color for occupancy percentage (heatmap)
  # Red (low) -> Yellow (medium) -> Green (high)
  def occupancy_color(percentage)
    if percentage >= 70
      'var(--spectrum-celery-400)' # green
    elsif percentage >= 40
      'var(--spectrum-yellow-400)' # yellow
    else
      'var(--spectrum-red-400)' # red
    end
  end
end
