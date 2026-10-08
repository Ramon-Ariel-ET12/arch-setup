import GObject from "gi://GObject?version=2.0"
import Gtk from "gi://Gtk?version=4.0"
import { intrinsicElements } from "ags/gtk4/jsx-runtime"
import type { CCProps } from "gnim"

/**
 * Registers extra JSX intrinsic elements missing from the default AGS
 * runtime registry. Import once from the app entry (side-effect module).
 */

type Props<T extends GObject.Object, P> = CCProps<T, Partial<P>>

type FlowBoxProps = Props<Gtk.FlowBox, Gtk.FlowBox.ConstructorProps>
type FlowBoxChildProps = Props<Gtk.FlowBoxChild, Gtk.FlowBoxChild.ConstructorProps>
type PictureProps = Props<Gtk.Picture, Gtk.Picture.ConstructorProps>
type SeparatorProps = Props<Gtk.Separator, Gtk.Separator.ConstructorProps>
type SpinnerProps = Props<Gtk.Spinner, Gtk.Spinner.ConstructorProps>
type FixedProps = Props<Gtk.Fixed, Gtk.Fixed.ConstructorProps>
type CalendarProps = Props<Gtk.Calendar, Gtk.Calendar.ConstructorProps>
type DropDownProps = Props<Gtk.DropDown, Gtk.DropDown.ConstructorProps>

Object.assign(intrinsicElements as Record<string, unknown>, {
    flowbox: Gtk.FlowBox,
    flowboxchild: Gtk.FlowBoxChild,
    picture: Gtk.Picture,
    separator: Gtk.Separator,
    spinner: Gtk.Spinner,
    fixed: Gtk.Fixed,
    calendar: Gtk.Calendar,
    dropdown: Gtk.DropDown,
})

declare global {
    namespace JSX {
        interface IntrinsicElements {
            flowbox: FlowBoxProps
            flowboxchild: FlowBoxChildProps
            picture: PictureProps
            separator: SeparatorProps
            spinner: SpinnerProps
            fixed: FixedProps
            calendar: CalendarProps
            dropdown: DropDownProps
        }
    }
}

export {}
