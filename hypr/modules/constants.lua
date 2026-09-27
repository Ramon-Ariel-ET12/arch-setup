-- Global constants shared across modules. Must load before anything using them.
_G.Hy = {
    mod = "SUPER",
    terminal = "kitty",
    file_manager = "nemo",
}

_G.env = {
    HOME = os.getenv("HOME"),
    PATH = os.getenv("PATH"),
}
