includes(os.scriptdir() .. "/groups.lua")

local TestGroupName = TEST_GROUP_NAME

local function check_targets(targets, leak_tool, project, os, verbose, build_params, leak_exit_code)
    local failing_targets = {}
    for _, target in ipairs(targets) do
        local target_name = target:name()
        local bin_path = target:targetfile()

        if not os.isfile(bin_path) then
            raise("Executable not found for target: " .. target_name)
        end

        print("Running leaks check on: " .. bin_path)
        local options = {try = true, curdir = path.directory(bin_path)}
        if not verbose then
            options.stdout = os.nuldev()
            options.stderr = os.nuldev()
        end
        local return_value = os.execv(leak_tool, build_params(bin_path), options)
        if return_value ~= 0 and (not leak_exit_code or return_value == leak_exit_code) then
            table.insert(failing_targets, target_name)
        elseif return_value ~= 0 then
            raise(target_name .. " exited with code " .. return_value .. " during its leak check.")
        end
    end
    return failing_targets
end

local function macos_params(bin_path)
    return {
        "--atExit",
        "-exclude", "-[LNProcessInstanceRegistryClient makeXPCConnection]",
        "--", bin_path
    }
end

local function linux_params(bin_path)
    return {
        "--leak-check=full",
        "--show-leak-kinds=definite,indirect",
        "--errors-for-leak-kinds=definite,indirect",
        "--error-exitcode=99",
        "--suppressions=" .. path.join(os.projectdir(), "tools", "valgrind", "glfw.supp"),
        bin_path
    }
end

local function windows_params(bin_path)
    return {
        "-batch",
        "-brief",
        "-check_leaks",
        "-exit_code_if_errors", "99",
        "--", bin_path
    }
end

task("check_leaks")
    on_run(function ()
        import("core.base.option")
        import("core.project.project")
        import("core.project.config")
        import("lib.detect.find_program")

        local wanted_target = option.get("targets") or {}
        local targets = {}
        if #wanted_target == 0 then
            for _, target in pairs(project:targets()) do
                local name = target:name()
                local group = target:info().group
                local kind = target:kind()
                if kind == "binary" and group == TestGroupName then
                    table.insert(targets, target)
                end
            end
        else
            for _, target in pairs(project:targets()) do
                local name = target:name()
                local group = target:info().group
                local kind = target:kind()
                if kind == "binary" and group == TestGroupName then
                    for _, wanted in ipairs(wanted_target) do
                        if name == wanted then
                            table.insert(targets, target)
                            break
                        end
                    end
                end
            end
        end

        table.sort(targets, function(first, second)
            return first:name() < second:name()
        end)

        local failing_targets = {}
        local host = os.host()
        if host == "macosx" then
            local leaks_tool = find_program("leaks", { check = "--help" })
            if not leaks_tool then
                raise("leaks is required to check memory leaks on macOS.")
            end
            failing_targets = check_targets(
                targets, leaks_tool, project, os, option.get("verbose"), macos_params, 1)
        elseif host == "linux" then
            local valgrind = find_program("valgrind", { check = "--version" })
            if not valgrind then
                raise("Valgrind is required to check memory leaks on Linux.")
            end
            failing_targets = check_targets(
                targets, valgrind, project, os, option.get("verbose"), linux_params, 99)
        elseif host == "windows" then
            local drmemory = find_program("drmemory", { check = "-version" })
            if not drmemory then
                raise("Dr. Memory is required to check memory leaks on Windows.")
            end
            failing_targets = check_targets(
                targets, drmemory, project, os, option.get("verbose"), windows_params, 99)
        else
            raise("Memory leak checking is not supported on " .. host .. ".")
        end
        if #failing_targets > 0 then
            print("Targets with memory leaks found:")
            for _, target in ipairs(failing_targets) do
                print("  - " .. target)
            end
            raise("Memory leaks detected in " .. #failing_targets .. " target(s).")
        else
            print("No memory leaks found.")
        end
    end)

    set_menu {
        usage = "xmake check_leaks",
        description = "Check for memory leaks",
        options = {
            {nil, "targets", "vs", nil, "Targets to check for leaks (default: all test targets)"}
        }
    }
