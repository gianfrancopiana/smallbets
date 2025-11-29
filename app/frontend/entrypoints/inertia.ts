import { createInertiaApp, router } from "@inertiajs/react"
import { createElement, ReactNode } from "react"
import { createRoot } from "react-dom/client"
import type { Root } from "react-dom/client"
import { toast } from "sonner"

import { Toaster } from "../components/ui/sonner"

declare global {
  interface Window {
    __sbToastListenerAttached?: boolean
    __sb_page_boot_ts?: number
    __sbInertiaHandlersAttached?: boolean
  }
}

// Handle non-Inertia responses by doing a full page reload instead of showing the error iframe
// This happens when navigating back/forward to a non-Inertia (Turbo) page
function setupInertiaEventHandlers() {
  // Prevent duplicate registration
  if (window.__sbInertiaHandlersAttached) {
    return
  }
  window.__sbInertiaHandlersAttached = true

  // The 'invalid' event fires when Inertia receives a non-Inertia response (e.g., full HTML)
  // By calling preventDefault and doing a full page reload, we prevent Inertia's default
  // behavior of showing the response in an iframe modal
  router.on("invalid", (event) => {
    event.preventDefault()
    // Use location.reload() for back/forward navigation to get fresh content
    window.location.reload()
  })

  // The 'exception' event fires on unexpected errors - also do a full page reload
  router.on("exception", (event) => {
    event.preventDefault()
    window.location.reload()
  })
}

// Temporary type definition, until @inertiajs/react provides one
type ResolvedComponent = {
  default: ReactNode
  layout?: (page: ReactNode) => ReactNode
}

type ToastVariant = "success" | "error" | "info" | "warning" | "message"

interface ToastEventDetail {
  message: string
  type?: ToastVariant
}

const TOAST_EVENT = "toast:show"

let toastRoot: Root | null = null

function bootInertiaApp() {
  const mount = document.getElementById("app") as HTMLElement | null

  if (!mount) {
    return
  }

  if (mount.dataset.inertiaMounted === "true") {
    return
  }

  const pagePayload = mount.dataset.page

  if (!pagePayload) {
    return
  }

  const initialPage = JSON.parse(pagePayload)

  // Mark page boot for early-mousemove suppression during initial render
  window.__sb_page_boot_ts = performance.now?.() ?? Date.now()

  createInertiaApp({
    id: mount.id,
    page: initialPage,
    resolve: (name) => {
      const pages = import.meta.glob<ResolvedComponent>("../pages/**/*.tsx", {
        eager: true,
      })
      const page = pages[`../pages/${name}.tsx`]
      if (!page) {
        console.error(`Missing Inertia page component: '${name}.tsx'`)
      }

      return page
    },
    setup({ el, App, props }) {
      if (!el) {
        console.error(
          "Missing root element.\n\n" +
            "If you see this error, it probably means you load Inertia.js on non-Inertia pages.\n" +
            'Consider moving <%= vite_typescript_tag "inertia" %> to the Inertia-specific layout instead.',
        )
        return
      }

      const root = createRoot(el)
      root.render(createElement(App, props))
      mount.dataset.inertiaMounted = "true"
    },
  }).catch((error) => {
    console.error("[Inertia] Failed to bootstrap page", error)
  })
}

function mountToaster() {
  const container = document.getElementById(
    "toast-portal",
  ) as HTMLElement | null

  if (!container) {
    return
  }

  if (container.dataset.reactMounted === "true" && toastRoot) {
    return
  }

  toastRoot = createRoot(container)
  toastRoot.render(createElement(Toaster))
  container.dataset.reactMounted = "true"
}

function showToast(message: string, type: ToastVariant = "success") {
  if (!message) return

  mountToaster()

  if (type === "message") {
    toast.message(message)
    return
  }

  const variantMap: Partial<
    Record<Exclude<ToastVariant, "message">, (value: string) => void>
  > = {
    success: toast.success,
    error: toast.error,
    info: toast.info,
    warning: toast.warning,
  }

  const variant = variantMap[type]

  if (variant) {
    variant(message)
    return
  }

  toast(message)
}

function handleToastEvent(event: Event) {
  if (!("detail" in event)) return

  const customEvent = event as CustomEvent<ToastEventDetail>
  if (!customEvent.detail?.message) return

  showToast(customEvent.detail.message, customEvent.detail.type)
}

function ensureToastListener() {
  if (window.__sbToastListenerAttached) {
    return
  }

  window.addEventListener(TOAST_EVENT, handleToastEvent)
  window.__sbToastListenerAttached = true
}

function flushFlashMessages() {
  const inertiaRoot = document.getElementById("app") as HTMLElement | null
  const isInertiaPage = Boolean(inertiaRoot?.dataset.page)

  if (isInertiaPage) {
    return
  }

  const flashContainers = document.querySelectorAll<HTMLElement>(
    "[data-flash-container]",
  )

  flashContainers.forEach((container) => {
    const notice = container.dataset.flashNotice
    const alert = container.dataset.flashAlert

    if (notice) {
      showToast(notice, "success")
      delete container.dataset.flashNotice
    }

    if (alert) {
      showToast(alert, "error")
      delete container.dataset.flashAlert
    }
  })
}

function bootToaster() {
  mountToaster()
  ensureToastListener()
  flushFlashMessages()
}

function boot() {
  setupInertiaEventHandlers()
  bootInertiaApp()
  bootToaster()
}

// Boot on initial page load
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", boot)
} else {
  boot()
}

// Also boot after Turbo navigations - this handles the case where user is on a Turbo page
// and clicks a link to an Inertia page. Turbo will swap the body, but the Inertia app
// needs to be booted since DOMContentLoaded won't fire again.
document.addEventListener("turbo:load", boot)

// Handle browser back-forward cache (bfcache) restoration
// When a page is restored from bfcache, the JavaScript state might be stale
// Force a reload to ensure fresh content
window.addEventListener("pageshow", (event) => {
  if (event.persisted) {
    // Page was restored from bfcache - reload to get fresh state
    window.location.reload()
  }
})
