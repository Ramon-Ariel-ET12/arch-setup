// Ambient declarations for non-TS imports.
// AGS v3 resolves gi:// and package imports via @girs + node_modules;
// nothing extra is needed here anymore.

declare module "inline:*" {
    const content: string
    export default content
}

// libadwaita is not installed on this system; ags/gnim import it optionally.
declare module "gi://Adw" {
    namespace Adw {
        class ToggleGroup {
            [key: string]: any
        }
    }
    const Adw: typeof Adw & { init(): void }
    export default Adw
}

declare module "gi://Adw?version=1" {
    const Adw: any
    export default Adw
}
