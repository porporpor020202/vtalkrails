export function trackMarketingEvent(name, details = {}) {
  const endpoint = document.querySelector('meta[name="marketing-events-url"]')?.content
  if (!endpoint) return
  fetch(endpoint, {
    method: "POST", credentials: "same-origin", keepalive: true,
    headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" },
    body: JSON.stringify({ name, ...details })
  }).catch(() => {})
}
