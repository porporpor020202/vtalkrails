const WIDTH = 1080
const HEIGHT = 1350
const FONT = '-apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", sans-serif'

async function loadImage(url) {
  const image = new Image()
  image.src = url
  await image.decode()
  return image
}

function text(ctx, value, x, y, size, color, weight = 500) {
  ctx.font = `${weight} ${size}px ${FONT}`
  ctx.textAlign = "center"
  ctx.textBaseline = "alphabetic"
  ctx.fillStyle = color
  ctx.fillText(value, x, y)
}

function lines(ctx, value, width) {
  return value.split("\n").flatMap(paragraph => {
    const chunks = paragraph.match(/\S+\s*/gu) || [""]
    const result = []
    let line = ""
    for (const chunk of chunks) {
      // Break long CJK phrases into characters; keep Latin words together.
      const parts = ctx.measureText(chunk.trim()).width > width ? Array.from(chunk) : [chunk]
      for (const part of parts) {
        if (line && ctx.measureText((line + part).trimEnd()).width > width) { result.push(line.trim()); line = "" }
        line += part
      }
    }
    result.push(line.trim())
    return result
  })
}

function fittedText(ctx, value, { top, width, height, size, weight = 800, color = "#244b3c", minSize = 22, truncate = false }) {
  const lineHeight = 1.2
  let wrapped
  while (true) {
    ctx.font = `${weight} ${size}px ${FONT}`
    wrapped = lines(ctx, value, width)
    if (wrapped.length * size * lineHeight <= height || size <= minSize) break
    size = Math.max(minSize, size - 2)
  }
  if (truncate && wrapped.length * size * lineHeight > height) {
    const count = Math.max(1, Math.floor(height / (size * lineHeight)))
    wrapped = wrapped.slice(0, count)
    let last = wrapped[count - 1]
    while (ctx.measureText(`${last}…`).width > width && last) last = last.slice(0, -1)
    wrapped[count - 1] = `${last.trimEnd()}…`
  }
  const baseline = top + (height - wrapped.length * size * lineHeight) / 2 + size * .9
  wrapped.forEach((line, index) => text(ctx, line, WIDTH / 2, baseline + index * size * lineHeight, size, color, weight))
}

export async function renderPracticeShareCard(data) {
  await document.fonts.ready
  const [mascot, appStore, googlePlay] = await Promise.all([
    loadImage(data.mascotUrl), loadImage(data.appStoreBadgeUrl), loadImage(data.googlePlayBadgeUrl)
  ])
  const canvas = document.createElement("canvas")
  canvas.width = WIDTH
  canvas.height = HEIGHT
  const ctx = canvas.getContext("2d", { alpha: false })
  ctx.fillStyle = "#f6f0e4"
  ctx.fillRect(0, 0, WIDTH, HEIGHT)

  text(ctx, "Say One Thing", WIDTH / 2, 112, 36, "#315844", 750)
  fittedText(ctx, data.headline, { top: 180, width: 920, height: 210, size: data.locale === "ko" ? 136 : 94, weight: 900 })
  if (data.sentences?.length) {
    text(ctx, data.sentenceLabel, WIDTH / 2, 430, 27, "#7c8a74", 500)
    fittedText(ctx, data.sentences.join("\n"), { top: 450, width: 880, height: 160, size: 48, weight: 600, minSize: 34, truncate: true })
    ctx.drawImage(mascot, 330, 622, 420, 420)
    fittedText(ctx, data.streakText, { top: 1040, width: 880, height: 100, size: 68 })
  } else {
    ctx.drawImage(mascot, 250, 408, 580, 580)
    fittedText(ctx, data.streakText, { top: 1012, width: 880, height: 112, size: 76 })
  }

  // Google supplies clear space inside its artwork. Keep both complete assets,
  // with matching visible badge heights and comfortable space around them.
  const appleHeight = 80
  const appleWidth = appStore.naturalWidth / appStore.naturalHeight * appleHeight
  const googleHeight = 106
  const googleWidth = googlePlay.naturalWidth / googlePlay.naturalHeight * googleHeight
  const gap = 32
  const start = (WIDTH - appleWidth - googleWidth - gap) / 2
  ctx.drawImage(appStore, start, 1170, appleWidth, appleHeight)
  ctx.drawImage(googlePlay, start + appleWidth + gap, 1157, googleWidth, googleHeight)
  fittedText(ctx, data.searchHint, { top: 1280, width: 920, height: 42, size: 32, weight: 600, color: "#62745f" })

  const blob = await new Promise((resolve, reject) => canvas.toBlob(value => value ? resolve(value) : reject(new Error("PNG encoding failed")), "image/png"))
  // Use one encoding for both the preview and native payload.
  const dataURL = await new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result)
    reader.onerror = () => reject(reader.error)
    reader.readAsDataURL(blob)
  })
  return { blob, dataURL }
}
