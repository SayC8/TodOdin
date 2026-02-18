package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"
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
    is_counter:    bool,
    count:         int,
}

get_db_path :: proc() -> string {
    home := os.get_env("HOME")
    if home == "" {
        home = os.get_env("USERPROFILE")
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

create_task :: proc(
    text: string,
    tasks: ^[dynamic]Task,
    is_counter: bool,
    initial_count: int = 0,
) {
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
    date_str := time.to_string_yy_mm_dd(now, buf[:])

    new_task := Task {
        text,
        strings.clone(date_str),
        false,
        is_counter,
        initial_count,
    }
    append(tasks, new_task)
    save_tasks(tasks^)
    fmt.printfln("%sTask added successfully.%s", COLOR_GREEN, COLOR_RESET)
    display_tasks(tasks)
}

adjust_count :: proc(index: int, tasks: ^[dynamic]Task, delta: int) {
    if index < 0 || index >= len(tasks) {
        fmt.printfln(
            "%sError: Index %d is invalid.%s",
            COLOR_RED,
            index + 1,
            COLOR_RESET,
        )
        return
    }

    if !tasks[index].is_counter {
        fmt.printfln(
            "%sError: Task %d is not a counter task.%s",
            COLOR_RED,
            index + 1,
            COLOR_RESET,
        )
        return
    }

    tasks[index].count += delta
    save_tasks(tasks^)
    fmt.printfln(
        "%sCount adjusted for task %d.%s",
        COLOR_GREEN,
        index + 1,
        COLOR_RESET,
    )
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
        "%sTask %d status toggled.%s",
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
    if !ok do return [dynamic]Task{}
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
        counter_info :=
            task.is_counter ? fmt.tprintf(" (Count: %d)", task.count) : ""
        line := fmt.tprintf(
            "%d: %s [%s]: %s%s",
            i + 1,
            status,
            task.creation_date,
            task.text,
            counter_info,
        )
        if len(line) > max_width {
            max_width = len(line)
        }
    }
    if max_width < 30 do max_width = 30

    print_border :: proc(char: byte, length: int) {
        for _ in 0 ..< length do fmt.printf("%c", char)
        fmt.println()
    }

    print_border('=', max_width)
    for task, i in tasks {
        color := task.done ? COLOR_GREEN : COLOR_RED
        status := task.done ? "[x]" : "[ ]"
        counter_info :=
            task.is_counter ? fmt.tprintf(" (Count: %d)", task.count) : ""

        fmt.printfln(
            "%d: %s%s%s [%s]: %s%s",
            i + 1,
            color,
            status,
            COLOR_RESET,
            task.creation_date,
            task.text,
            counter_info,
        )

        if i + 1 == len(tasks) do print_border('=', max_width)
        else do print_border('-', max_width)
    }
}

main :: proc() {
    tasks := load_tasks()
    defer delete(tasks)

    if len(os.args) < 2 {
        fmt.printfln(
            "%sUsage:%s tododin [add <text> | add-c <text> [amt] | list | done <idx> | inc <idx> [amt] | dec <idx> [amt] | delete <idx> | clear]",
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
        create_task(os.args[2], &tasks, false)
    case "add-c":
        if len(os.args) < 3 {
            fmt.println("Error: Please provide task text.")
            return
        }
        initial_count := 0
        if len(os.args) >= 4 {
            if val, ok := strconv.parse_int(os.args[3]); ok do initial_count = val
        }
        create_task(os.args[2], &tasks, true, initial_count)
    case "inc":
        if len(os.args) < 3 do return
        idx, ok_idx := strconv.parse_int(os.args[2])
        amount := 1
        if len(os.args) >= 4 {
            if val, ok := strconv.parse_int(os.args[3]); ok do amount = val
        }
        if ok_idx do adjust_count(idx - 1, &tasks, amount)
    case "dec":
        if len(os.args) < 3 do return
        idx, ok_idx := strconv.parse_int(os.args[2])
        amount := 1
        if len(os.args) >= 4 {
            if val, ok := strconv.parse_int(os.args[3]); ok do amount = val
        }
        if ok_idx do adjust_count(idx - 1, &tasks, -amount)
    case "done":
        if len(os.args) < 3 do return
        idx, ok := strconv.parse_int(os.args[2])
        if ok do toggle_done(idx - 1, &tasks)
    case "delete":
        if len(os.args) < 3 do return
        idx, ok := strconv.parse_int(os.args[2])
        if !ok {
            fmt.println("Error: Invalid index format.")
            return
        }
        delete_task(idx - 1, &tasks)
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
