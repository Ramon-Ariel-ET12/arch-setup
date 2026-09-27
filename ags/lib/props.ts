import type { Node } from "gnim"

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type AnyChildren = any

export interface BoxProps {
    class?: string
    spacing?: number
    hexpand?: boolean
    vexpand?: boolean
    widthRequest?: number
    heightRequest?: number
    children?: Node | Node[] | AnyChildren
}
