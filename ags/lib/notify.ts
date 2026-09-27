/**
 * Warn/error reporting: logs to console (→ logs.log) AND launches a desktop
 * notification, so failures surface as toasts (and land in the notifcenter
 * history) instead of only appearing in the log.
 *
 * Use `logWarn`/`logError` instead of `console.warn`/`console.error` — GJS
 * console methods are read-only, so interception is not possible.
 *
 * The shell itself is the notifd daemon, so the send path is a plain
 * `notify-send` subprocess that round-trips back into the toast UI. Spawning
 * (rather than using the Gtk app) keeps it working before `app.start()` —
 * e.g. for the boot-time SCSS compile error. Send failures are logged via
 * console directly and never re-enter this module, so a broken notification
 * daemon cannot recurse.
 */

export { logWarn, logError, installErrorReporting } from "@/lib/error-reporter"
export { logInfo } from "@/lib/log"
