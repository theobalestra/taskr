package taskrio

import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:strings"

import "../constants"

@(private)
EXPLAINER :: "\n# Anything above this line will be used for the task description.\n# Descriptions will be written in a markdown format"

get_user_description_input :: proc(id: string, allocator := context.allocator) -> (string, bool) {
	tmp_dir, tmp_err := os.temp_directory(context.temp_allocator)
	if tmp_err != nil {
		log.fatalf("could not get tmp dir: %v", tmp_err)
		return "", false
	}


	taskr_tmp_dir, alloc_err := filepath.join(
		[]string{tmp_dir, constants.CONFIG_DIR},
		context.temp_allocator,
	)

	if alloc_err != nil {
		log.fatalf("could not allocate: %v", alloc_err)
		return "", false
	}

	if (!os.exists(taskr_tmp_dir) || !os.is_dir(taskr_tmp_dir)) {
		make_tmp_err := os.make_directory_all(taskr_tmp_dir)
		if make_tmp_err != nil {
			log.fatalf("could not make tmp dir to get input: %v", make_tmp_err)
			return "", false
		}
	}

	tmp_name := fmt.tprintfln("tmp_%s", id)

	file_path: string
	file_path, alloc_err = filepath.join([]string{taskr_tmp_dir, tmp_name}, context.temp_allocator)
	if alloc_err != nil {
		log.errorf("could not allocate: %v", alloc_err)
		return "", false
	}

	make_err := os.write_entire_file_from_string(file_path, EXPLAINER)
	if make_err != nil {
		log.errorf("failed to make tmp file: %v", make_err)
		return "", false
	}

	defer os.remove(file_path)

	cmd := os.Process_Desc {
		command = []string{"vim", file_path},
		stderr  = os.stderr,
		stdin   = os.stdin,
		stdout  = os.stdout,
	}

	p, p_err := os.process_start(cmd)
	if p_err != nil {
		log.errorf("failed to open for input: %v", p_err)
		return "", false
	}

	s, pw_err := os.process_wait(p)
	if pw_err != nil {
		log.errorf("failed to wait for input: %v", pw_err)
		return "", false
	}

	f, f_err := os.open(file_path)
	if f_err != nil {
		log.errorf("failed to open tmp file: %v", f_err)
		return "", false
	}

	contents, r_err := os.read_entire_file_from_file(f, context.allocator)
	if f_err != nil {
		log.errorf("failed to open tmp file: %v", f_err)
		return "", false
	}
	defer delete(contents)

	str_contents := string(contents)

	idx_of_explainer := strings.index(str_contents, EXPLAINER)
	if idx_of_explainer == -1 {
		return "", true
	}

	return strings.clone(str_contents[:idx_of_explainer], allocator), true
}
