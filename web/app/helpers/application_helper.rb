module ApplicationHelper
  def status_badge_content(status)
    icon = case status
    when "pending"
      '<svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linejoin="miter"><polygon points="12,2 22,12 12,22 2,12"/></svg>'
    when "processing"
      '<svg class="w-3 h-3 animate-spin" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="square"><path d="M12 2 A10 10 0 1 1 2 12"/></svg>'
    when "done"
      '<svg class="w-3 h-3" viewBox="0 0 24 24" fill="currentColor"><polygon points="13,2 6,13 12,13 11,22 18,11 12,11"/></svg>'
    when "failed"
      # Skull & crossbones
      '<svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a7 7 0 0 0-7 7c0 2.4 1.2 4.5 3 5.7V17h8v-2.3c1.8-1.2 3-3.3 3-5.7a7 7 0 0 0-7-7zm-2 8a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm4 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm-5 7h6v1a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1v-1z"/><line x1="4" y1="20" x2="20" y2="20" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><line x1="5" y1="17" x2="19" y2="23" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><line x1="19" y1="17" x2="5" y2="23" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>'
    end
    "#{icon} #{status.capitalize}".html_safe
  end

  def stem_icon(stem)
    case stem
    when "bass"
      # Turntable — platter with tonearm
      '<svg class="w-8 h-8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="13" r="9"/><circle cx="11" cy="13" r="3"/><circle cx="11" cy="13" r="0.5" fill="currentColor" stroke="none"/><line x1="14" y1="10" x2="21" y2="3" stroke-width="2.5"/><line x1="21" y1="3" x2="23" y2="5" stroke-width="2.5"/></svg>'
    when "drums"
      # MPC pad grid — 4 pads like an MPC controller
      '<svg class="w-8 h-8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square"><rect x="2" y="2" width="9" height="9" rx="1"/><rect x="13" y="2" width="9" height="9" rx="1"/><rect x="2" y="13" width="9" height="9" rx="1"/><rect x="13" y="13" width="9" height="9" rx="1"/></svg>'
    when "vocals"
      # MIDI keyboard — keys with a black key accent
      '<svg class="w-8 h-8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square"><rect x="1" y="4" width="22" height="16" rx="1"/><line x1="5" y1="4" x2="5" y2="20"/><line x1="9" y1="4" x2="9" y2="20"/><line x1="13" y1="4" x2="13" y2="20"/><line x1="17" y1="4" x2="17" y2="20"/><line x1="21" y1="4" x2="21" y2="20"/><rect x="3" y="4" width="3" height="9" fill="currentColor" stroke="none"/><rect x="11" y="4" width="3" height="9" fill="currentColor" stroke="none"/><rect x="19" y="4" width="3" height="9" fill="currentColor" stroke="none"/></svg>'
    when "other"
      # Mixer faders — vertical channel strip
      '<svg class="w-8 h-8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="4" y1="3" x2="4" y2="21"/><line x1="12" y1="3" x2="12" y2="21"/><line x1="20" y1="3" x2="20" y2="21"/><rect x="2" y="6" width="4" height="3" rx="0.5" fill="currentColor" stroke="none"/><rect x="10" y="13" width="4" height="3" rx="0.5" fill="currentColor" stroke="none"/><rect x="18" y="9" width="4" height="3" rx="0.5" fill="currentColor" stroke="none"/></svg>'
    end.html_safe
  end
end
