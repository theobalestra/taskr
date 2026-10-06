package tasks

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"

import "../constants"

TaskError :: enum u32 {
	None = 0,
	UnknownTaskStatus,
}

TaskStatus :: enum u32 {
	Filed,
	InProgress,
	Done,
	WontDo,
}

@(private)
TASK_FILE_NAME :: "task.task"

@(private)
DESC_FILE_NAME :: "description.md"

parse_task_status :: proc(status: string) -> (TaskStatus, bool) {
	switch status {
	case "filed", "":
		return .Filed, true
	case "in_progress":
		return .InProgress, true
	case "done":
		return .Done, true
	case "wontdo":
		return .WontDo, true
	}

	return .Filed, false
}

string_task_status :: proc(status: TaskStatus) -> string {
	switch status {
	case .Filed:
		return "filed"
	case .InProgress:
		return "in_progress"
	case .Done:
		return "done"
	case .WontDo:
		return "wontdo"
	}

	unreachable()
}

Task :: struct {
	status:        TaskStatus,
	priority:      int,
	id:            string,
	name:          string,
	author:        string,
	tags:          [dynamic]string,
	taskr_version: u8,
}

create_new_task :: proc(
	name: string,
	status: TaskStatus,
	priority: int,
	tags: [dynamic]string,
	author: string,
) -> Task {
	t := time.now()

	return Task {
		id = gen_id(t),
		status = status,
		name = name,
		priority = priority,
		author = author,
		tags = tags,
		taskr_version = constants.TASKR_SERIALIZE_VERSION,
	}
}

SerializeError :: union #shared_nil {
	os.Error,
	runtime.Allocator_Error,
}

persist_update :: proc(task: Task, description: ^string, taskr_dir: string) -> SerializeError {
	task_dir, alloc_err := filepath.join([]string{taskr_dir, task.id}, context.temp_allocator)
	if alloc_err != nil {
		log.fatalf("error allocating to get task dir name: %v", alloc_err)
		return alloc_err
	}

	if (!os.exists(task_dir) || !os.is_dir(task_dir)) {
		init_err := os.make_directory_all(task_dir)
		if init_err != nil {
			log.fatalf("error making directory %s: %s", task_dir, init_err)
			return init_err
		}
	}

	task_file: string
	task_file, alloc_err = filepath.join(
		[]string{task_dir, TASK_FILE_NAME},
		context.temp_allocator,
	)

	if alloc_err != nil {
		log.fatalf("error allocating to get task file name: %v", alloc_err)
		return alloc_err
	}

	f, f_err := os.open(task_file, os.File_Flags{.Read, .Create, .Trunc, .Write})
	if f_err != nil {
		log.fatalf("could not open file: %s", f_err)
		return f_err
	}

	defer os.close(f)

	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	fmt.sbprintf(&sb, "taskr_version: %d\n\n", task.taskr_version)
	fmt.sbprintf(&sb, "name: %s\n", task.name)
	fmt.sbprintf(&sb, "author: %s\n", task.author)
	fmt.sbprintf(&sb, "status: %s\n", string_task_status(task.status))
	fmt.sbprintf(&sb, "priority: %d\n", task.priority)
	if len(task.tags) > 0 {
		fmt.sbprint(&sb, "tags:\n")
		for tag in task.tags {
			fmt.sbprintf(&sb, "\t- %s\n", tag)
		}
	}

	str := strings.to_string(sb)
	os.write_string(f, str)

	if description != nil {
		desc_file: string
		desc_file, alloc_err = filepath.join(
			[]string{task_dir, DESC_FILE_NAME},
			context.temp_allocator,
		)

		if alloc_err != nil {
			log.fatalf("error allocating to get description file name: %v", alloc_err)
			return alloc_err
		}

		desc_f: ^os.File
		desc_f, f_err = os.open(desc_file, os.File_Flags{.Read, .Create, .Trunc, .Write})
		if f_err != nil {
			log.fatalf("could not open description file: %v", f_err)
			return f_err
		}

		defer os.close(desc_f)
		os.write_string(desc_f, description^)
	}

	return nil
}

List_For_Project_Handler :: proc(task: Task)

list_for_project :: proc(dir: string, cb: List_For_Project_Handler) -> os.Error {
	w := os.walker_create(dir)
	defer os.walker_destroy(&w)

	for info in os.walker_walk(&w) {
		_ = os.walker_error(&w) or_break

		log.debugf("at file: %s", info.fullpath)
	}

	if path, err := os.walker_error(&w); err != nil {
		log.fatalf("could not walk project: %v", err)
		return err
	}

	return nil
}

@(private)
gen_id :: proc(t: time.Time) -> string {
	dt, ok := time.time_to_datetime(t)
	assert(ok, "could not generate an id")

	sb, err := strings.builder_make()

	fmt.sbprintf(
		&sb,
		"%04d%02d%02d-%02d%02d%02d",
		dt.year,
		dt.month,
		dt.day,
		dt.hour,
		dt.minute,
		dt.second,
	)
	return strings.to_string(sb)
}
