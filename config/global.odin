package config

import "base:runtime"
import "core:bufio"
import "core:encoding/json"
import "core:fmt"
import "core:io"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:strings"

import "../constants"


GlobalConfig :: struct {
	username: string,
}

ProjectConfigError :: enum u32 {
	None,
	NotFound,
}

Error :: union #shared_nil {
	os.Error,
	bufio.Scanner_Error,
	runtime.Allocator_Error,
	json.Unmarshal_Error,
	json.Marshal_Error,
	ProjectConfigError,
}

resolve_global_config :: proc() -> (GlobalConfig, Error) {
	cfg: GlobalConfig

	dir_path, err := ensure_global_config_dir_exists()
	if err != nil {
		log.fatalf("Could not resolve base config dir: %v", err)
		return cfg, err
	}
	defer delete(dir_path)

	app_config_file, alloc_err := filepath.join(
		[]string{dir_path, constants.CONFIG_FILE_NAME},
		context.temp_allocator,
	)

	if alloc_err != nil {
		log.fatalf("could not allocate: %v", alloc_err)
		return cfg, alloc_err
	}

	if (os.exists(app_config_file)) {
		b: []byte

		b, err = os.read_entire_file(app_config_file, context.temp_allocator)
		if err != nil {
			log.fatalf("Could not read config file: %v", err)
			return cfg, err
		}

		unmarshal_error := json.unmarshal(b, &cfg)
		if unmarshal_error != nil {
			log.fatalf("could not unmarshal config file: %v", unmarshal_error)
		}
		return cfg, unmarshal_error
	}

	w_err := write_global_config(app_config_file, &cfg)
	if w_err != nil {
		log.fatalf("Could not write to config file: %v", w_err)
		return cfg, w_err
	}

	return cfg, nil
}

prompt_and_write_username :: proc(cfg: ^GlobalConfig) -> (bool, Error) {
	s: bufio.Scanner

	bufio.scanner_init(&s, os.to_stream(os.stdin), context.temp_allocator)
	defer bufio.scanner_destroy(&s)

	name: string

	input_loop: for {
		fmt.print("Enter your name: ")
		if !bufio.scan(&s) {
			err := bufio.scanner_error(&s)

			if err != nil {
				log.fatalf("error reading input: %v", err)
				return true, err
			}

			return false, nil
		}

		temp_name := bufio.scanner_text(&s)
		if temp_name == "" {
			fmt.println("invalid name, must contain characters")
			continue
		}

		name = strings.clone(string(temp_name))
		break input_loop
	}

	fmt.println("name", name)
	cfg^.username = name

	dir_path, path_err := ensure_global_config_dir_exists()
	if path_err != nil {
		log.fatalf("Could not resolve base config dir: %v", path_err)
		return true, path_err
	}
	defer delete(dir_path)

	app_config_file, alloc_err := filepath.join(
		[]string{dir_path, constants.CONFIG_FILE_NAME},
		context.temp_allocator,
	)

	if alloc_err != nil {
		log.fatalf("could not allocate: %v", alloc_err)
		return true, alloc_err
	}

	w_err := write_global_config(app_config_file, cfg)
	if w_err != nil {
		log.fatalf("could not write to config: %v", w_err)
		return true, w_err
	}

	return true, nil
}

destroy_global :: proc(cfg: ^GlobalConfig) {
	delete(cfg.username)
}

@(private)
ensure_global_config_dir_exists :: proc() -> (string, Error) {
	base_config, err := os.user_config_dir(context.temp_allocator)

	if err != nil {
		log.fatalf("Could not resolve base config dir: %v", err)
		return "", err
	}

	app_config_dir, alloc_err := filepath.join([]string{base_config, constants.CONFIG_DIR})

	if alloc_err != nil {
		log.fatalf("could not allocate: %v", alloc_err)
		return "", alloc_err
	}

	if (!os.exists(app_config_dir)) {
		err = os.make_directory_all(app_config_dir)
		if err != nil {
			delete(app_config_dir)
			log.fatalf("Could not make base config dir: %v", err)
			return "", err
		}
	}

	return app_config_dir, nil
}

@(private)
write_global_config :: proc(file_path: string, cfg: ^GlobalConfig) -> Error {
	f, err := os.open(file_path, os.File_Flags{.Write, .Create, .Read, .Trunc})
	if err != nil {
		log.fatalf("Could not open config file: %v", err)
		return err
	}

	defer os.close(f)

	s := os.to_writer(f)

	marshal_err := json.marshal_to_writer(s, cfg^, &json.Marshal_Options{pretty = true})

	if marshal_err != nil {
		log.fatalf("Could not write initial config to file: %v", marshal_err)
		return marshal_err
	}

	return nil
}
