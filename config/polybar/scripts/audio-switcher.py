#!/usr/bin/env python3
import subprocess


def run(cmd, input_text=None):
    return subprocess.run(cmd, input=input_text, capture_output=True, text=True).stdout


def parse_pactl_list(kind):
    header = kind[:-1].capitalize() + " #"
    out = run(["pactl", "list", kind])
    items = []
    name = None
    for line in out.splitlines():
        line = line.strip()
        if line.startswith(header):
            name = None
        elif line.startswith("Name: "):
            name = line.split("Name: ", 1)[1]
        elif line.startswith("Description: "):
            desc = line.split("Description: ", 1)[1]
            if name and not name.endswith(".monitor"):
                items.append((desc, name))
    return items


def rofi_pick(options, prompt):
    menu = "\n".join(desc for desc, _ in options)
    choice = run(["rofi", "-dmenu", "-i", "-p", prompt], menu).strip()
    for desc, name in options:
        if desc == choice:
            return name
    return None


def main():
    mode = run(["rofi", "-dmenu", "-i", "-p", "Audio"], "Output\nInput").strip()
    if mode == "Output":
        choice = rofi_pick(parse_pactl_list("sinks"), "Output")
        if choice:
            subprocess.run(["pactl", "set-default-sink", choice])
    elif mode == "Input":
        choice = rofi_pick(parse_pactl_list("sources"), "Input")
        if choice:
            subprocess.run(["pactl", "set-default-source", choice])


if __name__ == "__main__":
    main()
