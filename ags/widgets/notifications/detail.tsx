import { Gtk } from "ags/gtk4"
import type AstalNotifd from "gi://AstalNotifd?version=0.1"
import { openUri } from "@/system/xdg/desktop"
import Pango from "gi://Pango?version=1.0"
import { For, With, createBinding, createEffect } from "gnim"
import { AppIcon, Button, Card, Popup } from "@/components"
import { icons } from "@/lib/icons"
import { closePopup, openPopup } from "@/services/popups"
import {
    currentDetailId,
    findLive,
    notificationHistory,
    toggleSelectionMode,
} from "./history"
import { useNotification, useSavedNotification } from "./notification"

/**
 * Notification detail popup. Opens via `openDetail(id)` (see `history.ts`).
 * Renders the history record for `currentDetailId()` — live daemon objects
 * keep invokable actions, saved snapshots render read-only. The `With`
 * re-renders the body whenever the selection changes. If the record is
 * deleted while the popup is open, the popup closes itself.
 *
 * Toggle: `ags toggle notifdetail` — usually opened indirectly from the center.
 */

const DETAIL_BODY_LIMIT = 4000

export default function NotificationDetail() {
    // Deleted while open → close the detail popup.
    createEffect(() => {
        const id = currentDetailId()
        if (
            id !== null &&
            !notificationHistory().some(
                (r) => (r.kind === "live" ? r.notification.id : r.saved.id) === id,
            )
        ) {
            closePopup("notifdetail")
        }
    })

    return (
        <Popup
            name="notifdetail"
            title="Notification"
            target="main"
            widthPct={36}
            heightPct={70}
            showCloseButton
        >
            <With value={currentDetailId}>{(id) => <DetailBody id={id} />}</With>
        </Popup>
    )
}

function DetailBody({ id }: { id: number | null }) {
    if (id === null) {
        return (
            <Card>
                <label label="Notification no longer available" opacity={0.6} />
            </Card>
        )
    }
    // Live daemon object when still unresolved (actions invokable), else the
    // persisted snapshot (read-only — the sender may be gone).
    const live = findLive(id)
    if (live !== null) return <LiveDetailBody id={id} notification={live} />
    const record = notificationHistory().find(
        (r) => (r.kind === "live" ? r.notification.id : r.saved.id) === id,
    )
    if (record === undefined || record.kind === "live") {
        return (
            <Card>
                <label label="Notification no longer available" opacity={0.6} />
            </Card>
        )
    }
    const { summary, body, appIcon, image, relative, absolute } = useSavedNotification(record.saved)
    return (
        <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
            <DetailHeader
                summary={summary()}
                relative={relative}
                appIcon={appIcon()}
                image={image()}
            />
            <BodyWithLinks body={body()} />
            <DetailFooter absolute={absolute} />
        </box>
    )
}

function DetailHeader({ summary, relative, appIcon, image }: { summary: string; relative: string; appIcon: string; image: string }) {
    return (
        <box spacing={10}>
            <AppIcon
                name={appIcon}
                path={image}
                size={Gtk.IconSize.LARGE}
                pixelSize={48}
                valign={Gtk.Align.CENTER}
            />
            <box
                orientation={Gtk.Orientation.VERTICAL}
                hexpand
                spacing={2}
                valign={Gtk.Align.CENTER}
            >
                <label
                    class="bold text-body"
                    label={summary}
                    xalign={0}
                    wrap
                    ellipsize={Pango.EllipsizeMode.END}
                />
                <label
                    class="text-caption opacity-mid"
                    label={relative}
                    xalign={0}
                    opacity={0.6}
                />
            </box>
        </box>
    )
}

function DetailFooter({ absolute }: { absolute: string }) {
    return (
        <box class="mt-2" spacing={8}>
            <label
                class="text-micro opacity-mid"
                label={absolute}
                xalign={0}
                opacity={0.5}
                valign={Gtk.Align.CENTER}
            />
            <box hexpand />
            <Button
                icon={icons.ui.select}
                label="Select mode"
                variant="flat"
                valign={Gtk.Align.CENTER}
                onClicked={() => {
                    toggleSelectionMode()
                    closePopup("notifdetail")
                    openPopup("notifcenter")
                }}
            />
        </box>
    )
}

function LiveDetailBody({ id: _id, notification }: { id: number; notification: AstalNotifd.Notification }) {
    const { summary, body, appIcon, image, relative, absolute } = useNotification(notification)
    const actions = createBinding(notification, "actions")

    return (
        <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
            <DetailHeader
                summary={summary()}
                relative={relative()}
                appIcon={appIcon()}
                image={image()}
            />
            <BodyWithLinks body={body()} />
            <DetailFooter absolute={absolute()} />
            <For each={actions}>
                {(action) => (
                    <box class="mt-1">
                        <Button
                            icon={icons.ui.open}
                            label={action.label}
                            variant="primary"
                            onClicked={() => notification.invoke(action.id)}
                            hexpand
                        />
                    </box>
                )}
            </For>
        </box>
    )
}

function BodyWithLinks({ body }: { body: string }) {
    if (body === "") return <box />
    const spans = linkify(body)
    // No URLs → render plain. With URLs → render as a single Pango label using
    // <span foreground> markup. We avoid splitting into multiple labels so
    // Pango handles wrap, ellipsize, and link activation uniformly.
    if (spans.length === 0) {
        return (
            <label
                class="text-body"
                label={body}
                xalign={0}
                wrap
                useMarkup={false}
                maxWidthChars={80}
            />
        )
    }
    return (
        <label
            class="text-body rich-text"
            label={buildMarkup(body, spans)}
            xalign={0}
            wrap
            useMarkup
            maxWidthChars={80}
            $={(self: Gtk.Label) => {
                self.connect("activate-link", (_l, href: string) => {
                    void openUrl(href)
                })
            }}
        />
    )
}

function buildMarkup(text: string, spans: { start: number; end: number; href: string }[]): string {
    const out: string[] = []
    let cursor = 0
    const limit = Math.min(text.length, DETAIL_BODY_LIMIT)
    for (const s of spans) {
        if (s.start >= limit) break
        out.push(escape(text.slice(cursor, s.start)))
        out.push(
            `<a href="${escapeAttr(s.href)}">${escape(text.slice(s.start, Math.min(s.end, limit)))}</a>`,
        )
        cursor = Math.min(s.end, limit)
    }
    if (cursor < limit) out.push(escape(text.slice(cursor, limit)))
    if (text.length > limit) out.push("\n…")
    return out.join("")
}

function escape(s: string): string {
    return s
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
}

function escapeAttr(s: string): string {
    return escape(s).replace(/"/g, "&quot;")
}

// ---------------------------------------------------------------------------
// Link handling

const URL_RE = /\bhttps?:\/\/[^\s<>"']+[^\s<>"'.,;:!?)]/gi

interface LinkSpan {
    start: number
    end: number
    href: string
}

/** Find URLs in `body`; ranges are valid indexes into the same string. */
function linkify(body: string): LinkSpan[] {
    const out: LinkSpan[] = []
    for (const m of body.matchAll(URL_RE)) {
        const text = m[0]
        if (text === undefined) continue
        const start = m.index ?? 0
        out.push({ start, end: start + text.length, href: text })
    }
    return out
}

function openUrl(href: string): void {
    openUri(href)
}
