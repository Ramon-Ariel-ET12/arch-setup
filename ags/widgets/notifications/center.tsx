import { Gtk } from "ags/gtk4"
import { For, With } from "gnim"
import { Button, Card, Popup, ScrollArea } from "@/components"
import { icons } from "@/lib/icons"
import { NotificationCard } from "./card"
import { useNotification, useSavedNotification } from "./notification"
import {
    clearHistory,
    deleteSelected,
    dismissRecord,
    isSelected,
    isSelectionMode,
    notificationHistory,
    openDetail,
    selectedCount,
    setSelectionModeOn,
    toggleSelected,
    type HistoryRecord,
} from "./history"

/**
 * Notification center — the saved list. Reads the persisted history store
 * (`history.ts`: daemon snapshots + boot-rehydrated JSON), NOT the daemon's
 * live list, so entries survive toast expiry and reboots.
 *
 * Two modes:
 * - **List mode (default):** rows open their detail popup on click.
 * - **Selection mode:** rows become checkboxes; the header shows a
 *   "Delete (N)" action and a Cancel button. Multiple entries can be
 *   dismissed at once.
 *
 * Toggle: `ags toggle notifcenter`
 */
export default function NotificationCenter() {
    return (
        <Popup
            name="notifcenter"
            title="Notification Center"
            target="main"
            widthPct={36}
            heightPct={60}
        >
            <With value={isSelectionMode}>
                {(selecting) =>
                    selecting ? (
                        <box class="mb-2" spacing={6}>
                            <Button
                                icon={icons.ui.trash}
                                label={`Delete (${selectedCount()})`}
                                variant="danger"
                                sensitive={selectedCount() > 0}
                                onClicked={() => deleteSelected()}
                                hexpand
                            />
                            <Button
                                label="Cancel"
                                variant="flat"
                                onClicked={() => setSelectionModeOn(false)}
                            />
                        </box>
                    ) : (
                        <box class="mb-2" spacing={6}>
                            <Button
                                icon={icons.ui.select}
                                label="Select"
                                variant="flat"
                                onClicked={() => setSelectionModeOn(true)}
                            />
                            <box hexpand />
                            <Button
                                icon={icons.ui.trash}
                                label="Clear all"
                                variant="danger"
                                onClicked={() => clearHistory()}
                            />
                        </box>
                    )
                }
            </With>

            <ScrollArea vexpand>
                <For each={notificationHistory}>{(r) => <HistoryCard record={r} />}</For>
                <With value={notificationHistory((list) => list.length === 0)}>
                    {(empty) =>
                        empty ? (
                            <Card>
                                <label label="No notifications" opacity={0.5} />
                            </Card>
                        ) : (
                            <box />
                        )
                    }
                </With>
            </ScrollArea>
        </Popup>
    )
}

function recordId(record: HistoryRecord): number {
    return record.kind === "live" ? record.notification.id : record.saved.id
}

function HistoryCard({ record }: { record: HistoryRecord }) {
    const id = recordId(record)
    const selected = isSelected(id)

    const onClick = () => {
        if (isSelectionMode.peek()) toggleSelected(id)
        else openDetail(id)
    }

    const timeLabel =
        record.kind === "live"
            ? useNotification(record.notification).absolute
            : useSavedNotification(record.saved).absolute

    return (
        <button
            class={selected((s) => `row${s ? " row-selected" : ""}`)}
            onClicked={onClick}
            tooltipText={timeLabel}
        >
            <Card spacing={4}>
                <box spacing={8}>
                    <With value={isSelectionMode}>
                        {(selecting) =>
                            selecting ? (
                                <box
                                    class="min-w-0 px-3"
                                    halign={Gtk.Align.CENTER}
                                    valign={Gtk.Align.START}
                                >
                                    <image iconName={selected() ? icons.ui.check : ""} />
                                </box>
                            ) : (
                                <box />
                            )
                        }
                    </With>
                    <box hexpand valign={Gtk.Align.START}>
                        {record.kind === "live" ? (
                            <NotificationCard notification={record.notification} timeAlign={Gtk.Align.START} />
                        ) : (
                            <NotificationCard saved={record.saved} timeAlign={Gtk.Align.START} />
                        )}
                    </box>
                </box>
            </Card>
        </button>
    )
}

export { dismissRecord }
