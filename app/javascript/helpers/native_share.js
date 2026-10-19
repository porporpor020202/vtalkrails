const pending = new Map()
window.addEventListener("practice-share-result", event => {
  const request = pending.get(event.detail?.id)
  if (!request) return
  clearTimeout(request.timer)
  pending.delete(event.detail.id)
  if (event.detail.completed) request.resolve()
  else request.reject(new DOMException("Share cancelled", "AbortError"))
})

export function nativeShareAvailable() {
  return !!(window.webkit?.messageHandlers?.practiceShare || window.PracticeShare)
}

export function nativeShare(data) {
  const ios = window.webkit?.messageHandlers?.practiceShare
  const android = window.PracticeShare
  if (!ios && !android) return null
  return new Promise((resolve, reject) => {
    const id = crypto.randomUUID()
    const timer = setTimeout(() => { pending.delete(id); reject(new Error("Share timeout")) }, 180000)
    pending.set(id, { resolve, reject, timer })
    try {
      if (ios) ios.postMessage({ ...data, id })
      else android.postMessage(JSON.stringify({ ...data, id }))
    } catch (error) { clearTimeout(timer); pending.delete(id); reject(error) }
  })
}
