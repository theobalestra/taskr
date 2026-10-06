package main

import "constants"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strconv"
import "core:strings"

import "config"
import taskrio "io"
import "tasks"

CLI_Op_Handler :: proc(args: []string) -> int

print_flag_helper :: proc(flag: string, explainer: string) {
	fmt.printfln("\n\t%s\n\t\t%s", flag, explainer)
}

help :: proc(args: []string) -> int {
	fmt.println(constants.TAG_LINE)
	fmt.printfln(constants.USAGE_FMT, "command")
	fmt.println("Commands:")
	fmt.println("\tadd\tAdds a local task")
	fmt.println("\tinit\tInits the current directory for taskr")
	fmt.println("\nFor further details on a command, invoke command help:")
	fmt.println("\te.g. `taskr add -help`")

	return 0
}

parse_tags :: proc(tags: string) -> []string {
	tags := make([]string, 0)

	return tags
}

add :: proc(args: []string) -> int {
	arg_len := len(args)

	help := false
	error: string

	priority: int = 0
	status := tasks.TaskStatus.Filed

	name: string
	defer delete(name)

	tags: [dynamic]string
	defer delete(tags)

	for i := 0; i < arg_len && !help; i += 1 {
		flag := args[i]
		switch flag {
		case constants.PRIORITY_FLAG, constants.PRIORITY_LONG_FLAG:
			if (arg_len == i + 1) {
				error = fmt.tprintf("\"%s\" flag expects an number following it", flag)
				break
			}

			i += 1

			ok: bool
			priority, ok = strconv.parse_int(args[i])
			if !ok {
				error = fmt.tprintf(
					"\"%s\" flag expects an positive number following it, but got %s",
					flag,
					args[i],
				)
				break
			}
		case constants.STATUS_FLAG, constants.STATUS_LONG_FLAG:
			if (arg_len == i + 1) {
				error = fmt.tprintf("\"%s\" flag expects a status following it", flag)
				break
			}

			i += 1

			ok: bool
			status, ok = tasks.parse_task_status(args[i])
			if !ok {
				error = fmt.tprintf(
					"\"%s\" flag expects an status following it, but got %s",
					flag,
					args[i],
				)
				break
			}
		case constants.TAG_FLAG, constants.TAG_LONG_FLAG:
			if (arg_len == i + 1) {
				error = fmt.tprintf("\"%s\" flag expects an argument following it", flag)
				break
			}

			i += 1

			append(&tags, args[i])
		case constants.HELP_FLAG:
			help = true
		case:
			if len(name) > 0 {
				error = fmt.tprintf("unexpected arg \"%s\"", flag)
				break
			}

			start_idx := i
			end_idx := i
			name_loop: for ; end_idx < arg_len; end_idx += 1 {
				if args[end_idx][0] == '-' do break name_loop
			}

			name = strings.join(args[start_idx:end_idx], " ")
			i = end_idx - 1
		}
	}

	if error != "" {
		fmt.printfln("ERROR: %s", error)
		return 1
	}

	if (help) {
		fmt.println(constants.TAG_LINE)
		fmt.printfln(constants.USAGE_FMT, "add")
		fmt.println("\n\tadd\tAdds a local task")
		fmt.println("\t\tExamples:")
		fmt.println(
			"\t\t\ttaskr add task with long name                       Creates a task with the name",
		)
		fmt.println(
			"\t\t\ttaskr add -p 100 -status in_progress Add hellope    Creates a task with the specified priority, status, and name",
		)
		fmt.println(
			"\t\t\ttaskr add Add hellope -t starter -t \"Needs QA\"    Creates a task with the specified name and tags",
		)
		fmt.println("\n\tFlags\n")
		print_flag_helper(
			"-p,--priority",
			"Defines the priority for the task. Can be any positive or negative integer",
		)
		print_flag_helper(
			"-s,--status",
			"Defines the status for the task. Acceptable values are \"filed\",\"in_progress\",\"done\",\"wontdo\"",
		)
		print_flag_helper(
			"-t,--tags",
			"Defines the tags for the task. Multiple tags can be defined by chaining together -t arguments multiple times",
		)
		return 0
	}


	global_cfg, err := config.resolve_global_config()

	if err != nil {
		log.fatalf("Error loading global config: %v\n", err)
		return 1
	}

	defer config.destroy_global(&global_cfg)

	project_cfg: config.ProjectConfig
	project_cfg, err = config.resolve_project_config()

	if err != nil {
		log.fatalf("Error loading project config: %v\n", err)
		return 1
	}

	defer config.destroy_project(&project_cfg)


	if global_cfg.username == "" {
		success, err := config.prompt_and_write_username(&global_cfg)
		if err != nil {
			return 1
		}

		if !success {
			fmt.println("\nusername not inputed")
			return 1
		}
	}


	task := tasks.create_new_task(name, status, priority, tags, global_cfg.username)

	inp, ok := taskrio.get_user_description_input(task.id)
	if !ok {
		return 1
	}

	defer delete(inp)

	persist_err := tasks.persist_update(task, &inp, project_cfg.folder)
	if persist_err != nil {
		return 1
	}

	fmt.printfln("Task %s has been successfully created", task.id)
	return 0
}

list_tasks :: proc(args: []string) -> int {
	arg_len := len(args)

	help := false
	error: string

	for i := 0; i < arg_len && !help; i += 1 {
		flag := args[i]
		switch flag {
		case constants.HELP_FLAG:
			help = true
		case:
			error = fmt.tprintf("unexpected arg \"%s\"", flag)
			break
		}
	}

	if error != "" {
		fmt.printfln("ERROR: %s", error)
		return 1
	}

	if (help) {
		fmt.println(constants.TAG_LINE)
		fmt.printfln(constants.USAGE_FMT, "list")
		fmt.println("\n\tlist\tLists all tasks for the current project")
		fmt.println("\t\tExamples:")
		fmt.println("\t\t\ttaskr list  Lists all tasks for the current project")
		return 0
	}

	project_cfg, err := config.resolve_project_config(false)

	if err != nil {
		if err == config.ProjectConfigError.NotFound {
			fmt.println("No project found for the current directory")
			return 1
		}
		log.fatalf("Error loading project config: %v\n", err)
		return 1
	}

	defer config.destroy_project(&project_cfg)

	tasks.list_for_project(project_cfg.folder, proc(_: tasks.Task) {

	})
	return 0
}

version :: proc(args: []string) -> int {
	fmt.printfln("Taskr %s", constants.VERSION)
	return 0
}

init_project :: proc(args: []string) -> int {
	arg_len := len(args)

	help := false
	error: string

	for i := 0; i < arg_len && !help; i += 1 {
		flag := args[i]
		switch flag {
		case constants.HELP_FLAG:
			help = true
		case:
			error = fmt.tprintf("unexpected arg \"%s\"", flag)
		}
	}

	if error != "" {
		fmt.printfln("ERROR: %s", error)
		return 1
	}

	if (help) {
		fmt.println(constants.TAG_LINE)
		fmt.printfln(constants.USAGE_FMT, "init")
		fmt.println("\n\tinit\tInits the current directory for taskr")
		fmt.println("\t\tExamples:")
		fmt.println("\t\t\ttaskr init                       Initializes the current directory")
		return 0
	}

	wd, err := os.getwd(context.temp_allocator)
	if err != nil {
		log.fatalf("could not resolve working directory: %v", err)
		return 1
	}

	project_cfg, created, init_err := config.init_project(wd)

	if init_err != nil {
		log.fatalf("could not init taskr project: %v", init_err)
		return 1
	}

	if created {
		fmt.printfln("Project initialized at %s", project_cfg.folder)
	} else {
		fmt.printfln("Project already exists at %s", project_cfg.folder)
	}

	return 0
}

main :: proc() {
	_, debug := os.lookup_env("DEBUG", context.temp_allocator)
	level := log.Level.Info

	if debug {
		level = log.Level.Debug
	}

	context.logger = log.create_console_logger(level)

	args := os.args

	if len(args) < 2 {
		help(args)
		return
	}

	cmd := args[1]
	op: CLI_Op_Handler

	switch cmd {
	case "help":
		op = help
		break
	case "add":
		op = add
		break
	case "version":
		op = version
		break
	case "list":
		op = list_tasks
		break
	case "init":
		op = init_project
		break
	case:
		fmt.printf("Unrecognized command: %s\n", cmd)
		help(args)
		os.exit(1)
	}


	os.exit(op(args[2:]))
}
