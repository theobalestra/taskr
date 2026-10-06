package config

import "../constants"
import "core:log"
import "core:os"
import "core:path/filepath"

ProjectConfig :: struct {
	folder: string,
}

init_project :: proc(dir: string, allocator := context.allocator) -> (ProjectConfig, bool, Error) {
	cfg: ProjectConfig

	dir, created, err := init_dir(dir, allocator)
	if err != nil {
		return cfg, false, err
	}

	cfg.folder = dir

	return cfg, created, err
}

resolve_project_config :: proc(
	create_if_none := true,
	allocator := context.allocator,
) -> (
	ProjectConfig,
	Error,
) {
	cfg: ProjectConfig

	root_folder, err := resolve_project_root_folder(create_if_none, allocator)

	if err != nil {
		return cfg, err
	}

	cfg.folder = root_folder
	return cfg, nil
}

destroy_project :: proc(cfg: ^ProjectConfig) {
	delete(cfg.folder)
}

@(private)
resolve_project_root_folder :: proc(
	create_if_none := true,
	allocator := context.allocator,
) -> (
	string,
	Error,
) {
	wd, err := os.getwd(context.temp_allocator)
	if err != nil {
		log.fatalf("could not resolve working directory: %v", err)
		return "", err
	}

	dir := wd

	checker_loop: for {
		log.debugf("checking in directory: %v", dir)
		taskr_dir, alloc_err := filepath.join([]string{dir, constants.TASKR_DIR}, allocator)

		if alloc_err != nil {
			log.fatalf("could not allocate: %v", alloc_err)
			return "", alloc_err
		}

		if os.is_dir(taskr_dir) {
			return taskr_dir, nil
		}

		delete(taskr_dir)

		p := os.dir(dir)
		if p == "." || p == dir {
			break checker_loop
		}

		dir = p
	}

	if !create_if_none {
		return "", ProjectConfigError.NotFound
	}

	log.debugf("no dir found, initialitizing %v", wd)

	taskr_dir, created, init_err := init_dir(wd, allocator)
	if init_err != nil {
		return "", init_err
	}

	return taskr_dir, nil
}

@(private)
init_dir :: proc(dir: string, allocator := context.allocator) -> (string, bool, os.Error) {
	taskr_dir, err := filepath.join([]string{dir, constants.TASKR_DIR}, allocator)

	if err != nil {
		log.fatalf("error allocating: %v", err)
		return "", false, err
	}

	if (!os.exists(taskr_dir) || !os.is_dir(taskr_dir)) {
		init_err := os.make_directory_all(taskr_dir)
		if init_err != nil {
			log.fatalf("Could not make taskr dir: %v", init_err)

			delete(taskr_dir)
			return "", true, init_err
		}

		return taskr_dir, true, nil
	}

	return taskr_dir, false, nil
}
