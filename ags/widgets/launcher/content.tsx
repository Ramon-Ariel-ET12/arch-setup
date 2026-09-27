import { Gtk } from "ags/gtk4"
import Pango from "gi://Pango?version=1.0"
import { For, createComputed, createEffect, type Accessor } from "gnim"
import { ScrollArea, SearchEntry } from "@/components"
import { activeClass, scrollRangeIntoView } from "@/lib/ui"
import { icons } from "@/lib/icons"
import type { AppEntry } from "@/services/apps"
import {
  activeCursor,
  launchApp,
  results,
  searchText,
  setQuery,
} from "./actions"

/**
 * Launcher body: shared `SearchEntry` + ranked app list with a keyboard cursor.
 */
export function LauncherContent() {
  return (
    <box
      orientation={Gtk.Orientation.VERTICAL}
      spacing={8}
      class="p-1"
    >
      <SearchEntry
        text={searchText}
        onChangeText={setQuery}
        placeholder="Search applications…"
      />
      <ScrollArea>
        <box orientation={Gtk.Orientation.VERTICAL} spacing={2} class="list">
          <For each={results}>{AppRow}</For>
        </box>
      </ScrollArea>
    </box>
  )
}

function AppRow(app: AppEntry, index: Accessor<number>) {
  const active = createComputed(() => activeCursor() === index())
  let row: Gtk.Button | null = null

  // Keep the keyboard cursor visible: scroll on activation change and when
  // the active row (re)maps (fresh results, reopened popup).
  const scrollActiveIntoView = () => {
    if (row !== null) scrollRowIntoView(row)
  }
  createEffect(() => {
    if (active()) scrollActiveIntoView()
  })

  return (
    <button
      class={activeClass(active, "row")}
      onClicked={() => launchApp(app)}
      $={(self: Gtk.Button) => {
        row = self
        self.connect("map", () => {
          if (active.peek()) scrollActiveIntoView()
        })
      }}
    >
      <box spacing={10}>
        <image
          iconName={app.iconName || icons.ui.apps}
          iconSize={Gtk.IconSize.LARGE}
        />
        <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
          <label
            label={app.name}
            xalign={0}
            ellipsize={Pango.EllipsizeMode.END}
          />
          {app.description && (
            <label
              label={app.description}
              xalign={0}
              opacity={0.6}
              ellipsize={Pango.EllipsizeMode.END}
            />
          )}
        </box>
      </box>
    </button>
  )
}

/** Nudges the ancestor ScrolledWindow so `row` is fully in view. */
function scrollRowIntoView(row: Gtk.Button): void {
  const alloc = row.get_allocation()
  if (alloc.height === 0) return // not laid out yet
  scrollRangeIntoView(row, alloc.y, alloc.y + alloc.height)
}
