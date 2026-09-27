import { createBinding, For } from "gnim"
import { hypr } from "@/services/hyprland"

/**
 * Hyprland workspaces indicator. Click focuses the workspace through the
 * hyprsplit Lua dispatcher (`hl.dsp.focus { workspace = N }`). The Lua table
 * syntax is required — plain `hyprctl dispatch workspace N` semantics don't
 * apply under hyprsplit's per-monitor workspace model.
 */
export function Workspaces() {
    const workspaces = createBinding(hypr, "workspaces")((list) =>
        list.filter((w) => w.id > 0).sort((a, b) => a.id - b.id),
    )
    const focusedId = createBinding(hypr, "focused_workspace")((w) => w?.id ?? -1)

    function focusWorkspace(id: number): void {
        if (!Number.isInteger(id) || id <= 0) return
        hypr.dispatch("hl.dsp.focus", `{ workspace = ${id} }`)
    }

    return (
        <box class="card" spacing={2}>
            <For each={workspaces}>
                {(workspace) => (
                    <button
                        class={focusedId((id) =>
                            id === workspace.id ? "workspace-active" : "",
                        )}
                        onClicked={() => focusWorkspace(workspace.id)}
                    >
                        <label label={String(workspace.id)} />
                    </button>
                )}
            </For>
        </box>
    )
}
