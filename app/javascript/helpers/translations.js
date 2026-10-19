export function translate(key, values = {}) {
  const messages = JSON.parse(document.getElementById("ui-translations").textContent)
  return Object.entries(values).reduce((text, [name, value]) => text.replaceAll(`%{${name}}`, value), messages[key] || key)
}
