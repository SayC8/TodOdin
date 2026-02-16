package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:time"

COLOR_RESET :: "\x1b[0m"
COLOR_RED :: "\x1b[31m"
COLOR_GREEN :: "\x1b[32m"
COLOR_YELLOW :: "\x1b[33m"
COLOR_BOLD :: "\x1b[1m"

Task :: struct {
    text:          string,
    creation_date: string,
    done:          bool,
}

// Determines the path to .tododin in user's home directory
get_db_path :: proc() -> string {
    home := os.get_env("HOME")
    if home == "" {
        home = os.get_env("USERPROFILE") // Windows fallback
    }
    return filepath.join({home, ".tododin"})
}

save_tasks :: proc(tasks: [dynamic]Task) {
    path := get_db_path()
    defer delete(path)

    data, err := json.marshal(tasks, {pretty = true})
    if err != nil {
        fmt.eprintfln("JSON marshal error: %v", err)
        return
    }

    success := os.write_entire_file(path, data)
    if !success {
        fmt.println("Failed to write file to: %s", path)
    }
}

create_task :: proc(text: string, tasks: ^[dynamic]Task) {
    // Check for Duplicate check
    for task in tasks {
        if task.text == text {
            fmt.printfln(
                "%sError: Task '%s' already exists.%s",
                COLOR_RED,
                text,
                COLOR_RESET,
            )
            return
        }
    }

    now := time.now()
    buf: [time.MIN_YY_DATE_LEN]u8
    date: string = time.to_string_yy_mm_dd(now, buf[:])

    new_task := Task{text, date, false}
    append(tasks, new_task)
    save_tasks(tasks^)
    fmt.printfln("%sTask added successfully.%s", COLOR_GREEN, COLOR_RESET)
    display_tasks(tasks)
}

toggle_done :: proc(index: int, tasks: ^[dynamic]Task) {
    if index < 0 || index >= len(tasks) {
        fmt.printfln(
            "%sError: Index %d is invalid.%s",
            COLOR_RED,
            index + 1,
            COLOR_RESET,
        )
        return
    }

    tasks[index].done = !tasks[index].done
    save_tasks(tasks^)
    fmt.printfln(
        "%sTask %d marked as done%s.",
        COLOR_GREEN,
        index + 1,
        COLOR_RESET,
    )
    display_tasks(tasks)
}

delete_task :: proc(index: int, tasks: ^[dynamic]Task) {
    if index < 0 || index >= len(tasks) {
        fmt.printfln(
            "%sError: Index %d is invalid.%s",
            COLOR_RED,
            index + 1,
            COLOR_RESET,
        )
        return
    }

    ordered_remove(tasks, index)
    save_tasks(tasks^)
    fmt.printfln("%sTask deleted.%s", COLOR_RED, COLOR_RESET)
    display_tasks(tasks)
}

load_tasks :: proc() -> [dynamic]Task {
    path := get_db_path()
    defer delete(path)

    data, ok := os.read_entire_file(path)
    if !ok {
        return [dynamic]Task{}
    }
    defer delete(data)

    tasks: [dynamic]Task
    err := json.unmarshal(data, &tasks)
    if err != nil {
        fmt.eprintfln("JSON unmarshal error: %v", err)
        return [dynamic]Task{}
    }

    return tasks
}

display_tasks :: proc(tasks: ^[dynamic]Task) {
    if len(tasks) == 0 {
        fmt.println("No tasks found.")
        return
    }

    max_width := 0
    for task, i in tasks {
        status := task.done ? "[x]" : "[ ]"
        line := fmt.tprintf(
            "%d: %s [%s]: %s",
            i + 1,
            status,
            task.creation_date,
            task.text,
        )
        if len(line) > max_width {
            max_width = len(line)
        }
    }

    if max_width < 30 do max_width = 30

    print_border :: proc(char: byte, length: int) {
        for _ in 0 ..< length {
            fmt.printf("%c", char)
        }
        fmt.println()
    }

    print_border('=', max_width)
    for task, i in tasks {
        color := task.done ? COLOR_GREEN : COLOR_RED
        status := task.done ? "[x]" : "[ ]"
        fmt.printfln(
            "%d: %s%s%s [%s]: %s",
            i + 1,
            color,
            status,
            COLOR_RESET,
            task.creation_date,
            task.text,
        )

        if i + 1 == len(tasks) {
            print_border('=', max_width)
        } else {
            print_border('-', max_width)
        }
    }
}

main :: proc() {
    tasks: [dynamic]Task = load_tasks()
    defer delete(tasks)

    if len(os.args) < 2 {
        fmt.printfln(
            "%sUsage:%s tododin [add <text> | list | done <idx> | delete <idx>]",
            COLOR_BOLD,
            COLOR_RESET,
        )
        return
    }

    command := os.args[1]

    switch command {
    case "list":
        display_tasks(&tasks)
    case "add":
        if len(os.args) < 3 {
            fmt.println("Error: Please provide task text.")
            return
        }
        create_task(os.args[2], &tasks)
    case "done":
        if len(os.args) < 3 {
            fmt.println("Error: Please provide the task index.")
            return
        }
        idx, ok := strconv.parse_int(os.args[2])
        if ok do toggle_done(idx - 1, &tasks)
    case "delete":
        if len(os.args) < 3 {
            fmt.println("Error: Please provide the task index.")
            return
        }
        idx, ok := strconv.parse_int(os.args[2])
        if !ok {
            fmt.println("Error: Invalid index format.")
            return
        }
        if ok do delete_task(idx - 1, &tasks)
    case "clear":
        clear(&tasks)
        save_tasks(tasks)
        fmt.println("Task list cleared.")
    case:
        fmt.printfln(
            "%sUnknown command:%s %s",
            COLOR_RED,
            COLOR_RESET,
            command,
        )
    }
}
