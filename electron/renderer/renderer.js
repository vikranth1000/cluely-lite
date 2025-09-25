const input = document.getElementById('input')
const send = document.getElementById('send')
const transcript = document.getElementById('transcript')
const out = document.getElementById('out')
const closeBtn = document.getElementById('close')
const pill = document.getElementById('pill')
const resizeRight = document.querySelector('.resize-right')
const resizeBottom = document.getElementById('resize-bottom')
const btnSnap = document.getElementById('btn-snap')
const btnClick = document.getElementById('btn-click')
const btnFocus = document.getElementById('btn-focus')
const btnType = document.getElementById('btn-type')
const axTarget = document.getElementById('ax-target')
const axText = document.getElementById('ax-text')

async function submit() {
  const text = input.value.trim()
  if (!text) return
  out.textContent = '…'
  transcript.classList.remove('hidden')
  const res = await window.cluely.generate(text)
  if (res.ok) {
    out.textContent = res.text || '(empty)'
  } else {
    out.textContent = 'Error: ' + (res.error || 'unknown')
  }
}

send.addEventListener('click', submit)
input.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') submit()
})
closeBtn.addEventListener('click', () => transcript.classList.add('hidden'))

// Basic width resize by adjusting window bounds
let startX
let startW
resizeRight.addEventListener('mousedown', (e) => {
  e.preventDefault()
  startX = e.screenX
  startW = window.outerWidth
  window.addEventListener('mousemove', onResizeRight)
  window.addEventListener('mouseup', stopResizeRight, { once: true })
})

function onResizeRight(e) {
  const delta = e.screenX - startX
  window.resizeTo(Math.max(320, startW + delta), window.outerHeight)
}

function stopResizeRight() {
  window.removeEventListener('mousemove', onResizeRight)
}

// Basic height resize via bottom handle
let startY
let startH
resizeBottom.addEventListener('mousedown', (e) => {
  e.preventDefault()
  startY = e.screenY
  startH = window.outerHeight
  window.addEventListener('mousemove', onResizeBottom)
  window.addEventListener('mouseup', stopResizeBottom, { once: true })
})

function onResizeBottom(e) {
  const delta = e.screenY - startY
  const newH = Math.max(120, startH + delta)
  window.resizeTo(window.outerWidth, newH)
  // keep bottom handle positioned under the pill (simple offset)
  resizeBottom.style.top = (newH - 18) + 'px'
}

function stopResizeBottom() {
  window.removeEventListener('mousemove', onResizeBottom)
}

// AX helper integrations
btnSnap.addEventListener('click', async () => {
  const r = await window.cluely.ax.snapshot()
  transcript.classList.remove('hidden')
  out.textContent = r.ok ? JSON.stringify(r.json, null, 2) : 'Snapshot error: ' + (r.error || 'unknown')
})

btnClick.addEventListener('click', async () => {
  const target = axTarget.value.trim()
  if (!target) return
  const r = await window.cluely.ax.click(target)
  transcript.classList.remove('hidden')
  out.textContent = r.ok ? `Clicked: ${target}` : 'Click error: ' + (r.err || r.out || 'unknown')
})

btnFocus.addEventListener('click', async () => {
  const target = axTarget.value.trim()
  if (!target) return
  const r = await window.cluely.ax.focus(target)
  transcript.classList.remove('hidden')
  out.textContent = r.ok ? `Focused: ${target}` : 'Focus error: ' + (r.err || r.out || 'unknown')
})

btnType.addEventListener('click', async () => {
  const target = axTarget.value.trim()
  const text = axText.value
  if (!target) return
  const r = await window.cluely.ax.type(text, target)
  transcript.classList.remove('hidden')
  out.textContent = r.ok ? `Typed into '${target}'` : 'Type error: ' + (r.err || r.out || 'unknown')
})
