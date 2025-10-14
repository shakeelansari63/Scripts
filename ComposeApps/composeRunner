#!/bin/env python

import os
from pathlib import Path
import sys
import subprocess
from typing import Tuple
import time
import json


### Functions to run bash command
def run_bash_command(cmd: str) -> Tuple[int, str]:
    # Run Command and capture the output in variable
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

    # Combine Output and Errors in single variable for result
    output = (result.stderr + "\n" + result.stdout).strip("\n").strip()

    # Return Command RC and Output
    return (result.returncode, output)


def run_bash_command_with_output_stream(cmd: str) -> int:
    proc = subprocess.Popen(
        cmd,
        shell=True,
        stdout=sys.stdout,
        stderr=sys.stdout,
        stdin=sys.stdin,
    )

    # Wait till process is complete
    proc.wait()

    # Return Command RC
    return proc.returncode


# Compose Orchestrator
# This can be set to Docker or Podman
# Check if Compose Orchestrator ENV variable is set, yes then use it
COMPOSE_ORCHESTRATOR = os.getenv("COMPOSE_ORCHESTRATOR", "")

# If ENV Variable is not set, then try to find either docker or podman
if COMPOSE_ORCHESTRATOR == "":
    rc, _ = run_bash_command("type podman")

    if rc == 0:
        COMPOSE_ORCHESTRATOR = "podman"

    else:
        COMPOSE_ORCHESTRATOR = "docker"

# Command to check if Docker daemon is running
DOCKER_CHECK_CMD = f"{COMPOSE_ORCHESTRATOR} info > /dev/null 2>&1"

# Command to start Docker daemon
DOCKER_START_CMD = "dockup"

# Command to stop Docker daemon
DOCKER_STOP_CMD = "dockdown"

# Get current path withere Yamls are stored
APP_YAML_PATH = Path(os.path.dirname(os.path.abspath(__file__)))

# Get all supported Compose Apps
COMPOSE_APPS: dict[str, str] = {
    str(f).replace(str(APP_YAML_PATH), "").replace(".yml", "").replace(os.sep, ""): str(
        f
    )
    for f in APP_YAML_PATH.glob("*.yml")
}

# Supported Compose Runner Commands
COMPOSE_RUNNER_COMMANDS: dict[str, str] = {
    "--list-all": "List all the registered apps.",
    "--running": "List the running apps.",
    "--stop": "Lists the running apps and user can select an app and stop it.",
    "--stop-all": "Stop all running apps.",
    "--help": "Show this help page.",
}

# List of all supported Apps and Commands
COMPOSE_APPS_AND_COMMANDS: list[str] = [
    *list(COMPOSE_APPS.keys()),
    *list(COMPOSE_RUNNER_COMMANDS.keys()),
]

# Default Actions for each Compose App
DEFAULT_ACTION: dict[str, str] = {
    "start": "Start the app.",
    "stop": "Stop the app.",
    "restart": "Restart the app.",
    "log": "Show app logs.",
    "status": "Check whether app is running or not.",
    "top": "Show resource usage statistics of app.",
    "ssh": "SSH into app container.",
    "connect": "Show registered urls for connection to the app",
    "--help": "Show the app help",
}

EXTRA_ACTION: dict[str, dict[str, str]] = dict({})
EXTRA_CMD_ANNOTATION_PREFIX: str = "extracmd-"
EXTRA_CMDDESC_ANNOTATION_PREFIX: str = "extracmddesc-"

RUNNER_NAME = sys.argv[0].replace(str(APP_YAML_PATH), "").replace(os.sep, "")


# Generate List of additional supported actions for app through yaml annotations
def build_extra_actions_for_app(app: str) -> None:
    rc, json_config = run_bash_command(
        f"{COMPOSE_ORCHESTRATOR} compose -f {COMPOSE_APPS[app]} config --format json"
    )

    # Check if command was successful
    if rc != 0:
        return

    # Read Json config and get extra command details for each service
    config = json.loads(json_config)

    # Validate if services are defined
    if "services" not in config.keys() or len(config.get("services").keys()) == 0:
        return

    # If services are defined, loop over servcie and read extra command info from annotations
    for service_name, service_detail in config.get("services").items():
        # Check if annotations exist in service
        if service_detail.get("annotations") is None:
            continue

        # Extra Command Annotations
        extra_command_info = {
            annonkey.replace(EXTRA_CMD_ANNOTATION_PREFIX, ""): annonval
            for annonkey, annonval in service_detail.get("annotations").items()
            if annonkey.startswith(EXTRA_CMD_ANNOTATION_PREFIX)
        }

        # Check if any extra command info found
        if len(extra_command_info) == 0:
            continue

        extra_command_desc = {
            annonkey.replace(EXTRA_CMDDESC_ANNOTATION_PREFIX, ""): annonval
            for annonkey, annonval in service_detail.get("annotations").items()
            if annonkey.startswith(EXTRA_CMDDESC_ANNOTATION_PREFIX)
        }

        # Extract Command details and descriptions
        for cmd_name, cmd in extra_command_info.items():
            cmd_desc = extra_command_desc.get(cmd_name, None)
            EXTRA_ACTION[cmd_name] = {
                "service": service_name,
                "command": cmd,
                "description": cmd_desc
                if cmd_desc is not None
                else f"Run Command - {cmd} in {service_name} service",
            }


def check_docker_daemon_running() -> bool:
    # Check if Docker daemon running
    rc, _ = run_bash_command(DOCKER_CHECK_CMD)
    return rc == 0


def check_and_start_daemon() -> None:
    if not check_docker_daemon_running():
        # Start Docker daemon
        run_bash_command_with_output_stream(DOCKER_START_CMD)

        # Wait for max 30 seconds till Docker is up and running
        iter = 1
        while not check_docker_daemon_running() and iter < 30:
            time.sleep(1)
            iter += 1


def show_compose_runner_help() -> None:
    print(f"Usage: {RUNNER_NAME} <App-Name> <Action> [ Extra Args ]")
    print(f"Available Apps are [ {', '.join(COMPOSE_APPS.keys())} ]")
    print("")
    print("Other options: ")
    print("-" * 80)
    for action, action_description in COMPOSE_RUNNER_COMMANDS.items():
        print(f"{action:>15} : {action_description:<23}")


def show_compose_app_help(app: str) -> None:
    print("Valid Options are")
    print(
        f"{app} [ {' | '.join(list(DEFAULT_ACTION.keys()) + list(EXTRA_ACTION.keys()))} ]"
    )
    print("-" * 80)
    # Display Common actions
    for action, action_description in DEFAULT_ACTION.items():
        print(f"{action:>15} : {action_description:<23}")

    # Display additional actions for app
    for action, action_info in EXTRA_ACTION.items():
        action_description = action_info.get("description")
        print(f"{action:>15} : {action_description:<23}")


def get_running_compose_app_services(app: str) -> list[str]:
    rc, output = run_bash_command(
        f"{COMPOSE_ORCHESTRATOR} compose -f {COMPOSE_APPS[app]} ps --services --filter status=running"
    )
    if rc != 0:
        return []
    return output.splitlines()


def get_all_compose_app_services(app: str) -> list[str]:
    rc, output = run_bash_command(
        f"{COMPOSE_ORCHESTRATOR} compose -f {COMPOSE_APPS[app]} config --services"
    )
    if rc != 0:
        return []
    return output.splitlines()


def start_compose_app(app: str) -> None:
    check_and_start_daemon()

    # Check if app is already running
    if check_compose_app_status(app):
        print(f"App {app} is already running...")
        return

    # Start app
    print(f"Starting App {app} ...")

    rc = run_bash_command_with_output_stream(
        f"{COMPOSE_ORCHESTRATOR} compose -f {COMPOSE_APPS[app]} up -d --wait"
    )

    # Show connection info if app starts successfully
    if rc == 0:
        provide_connectivity_info(app)


def stop_compose_app(app: str) -> None:
    # Check if app is running or not
    if not check_compose_app_status(app):
        print(f"App {app} is not running...")
        return

    print(f"Stopping App {app} ...")
    run_bash_command_with_output_stream(
        f"{COMPOSE_ORCHESTRATOR} compose -f {COMPOSE_APPS[app]} down"
    )
    # Stop Docker daemon if no containers are running
    rc, output = run_bash_command(f"{COMPOSE_ORCHESTRATOR} ps -q")

    if rc == 0 and output.strip() == "" and COMPOSE_ORCHESTRATOR == "docker":
        print("No running containers found. Stopping Docker daemon ...")
        run_bash_command_with_output_stream(DOCKER_STOP_CMD)


def restart_compose_app(app: str) -> None:
    # Check if app is running or not
    if not check_compose_app_status(app):
        print(f"App {app} was not running...")
        start_compose_app(app)
        return

    print(f"Restarting App {app} ...")
    run_bash_command_with_output_stream(
        f"{COMPOSE_ORCHESTRATOR} compose -f {COMPOSE_APPS[app]} restart"
    )


def show_compose_app_logs(app: str) -> None:
    # Check if app is running or not
    if not check_compose_app_status(app):
        print(f"App {app} is not running...")
        return

    # Get all services for the app
    services = get_all_compose_app_services(app)

    # Return of no service is available
    if len(services) == 0:
        print(f"No services for app {app} ...")
        return

    # Directly Show log if there is only one service
    if len(services) == 1:
        run_bash_command_with_output_stream(
            f"{COMPOSE_ORCHESTRATOR} compose -f {COMPOSE_APPS[app]} logs {services[0]} --no-log-prefix "
        )
        return

    # Show Menu to select service
    for i in range(len(services)):
        print(f"[ {i + 1} ]: {services[i]}")
    print("[ 0 ]: All Services")

    service_idx = input("Select Service to see the Logs for ... ")

    # Validate Selection
    try:
        service_idx = int(service_idx)
    except ValueError:
        print("Invalid Selection ...")
        return
    if service_idx < 0 or service_idx > len(services):
        print("Invalid Selection ...")
        return

    # Show Logs for selected service
    if service_idx != 0:
        run_bash_command_with_output_stream(
            f"{COMPOSE_ORCHESTRATOR} compose -f {COMPOSE_APPS[app]} logs {services[service_idx - 1]} --no-log-prefix "
        )
        return

    run_bash_command_with_output_stream(
        f"{COMPOSE_ORCHESTRATOR} compose -f {COMPOSE_APPS[app]} logs"
    )


def ssh_into_compose_app_container(app: str) -> None:
    # Check if app is running or not
    if not check_compose_app_status(app):
        print(f"App {app} is not running...")
        return

    # Get all running services for the app
    services = get_running_compose_app_services(app)

    # Return of no service is available
    if len(services) == 0:
        print(f"No running services for app {app} ...")
        return

    # Directly SSH if there is only one service
    if len(services) == 1:
        run_bash_command_with_output_stream(
            f"{COMPOSE_ORCHESTRATOR} compose -f {COMPOSE_APPS[app]} exec {services[0]} /bin/bash"
        )
        return

    # Show Menu to select service
    for i in range(len(services)):
        print(f"[ {i + 1} ]: {services[i]}")

    service_idx = input("Select Service to SSH into ... ")

    # Validate Selection
    try:
        service_idx = int(service_idx)
    except ValueError:
        print("Invalid Selection ...")
        return
    if service_idx < 1 or service_idx > len(services):
        print("Invalid Selection ...")
        return

    # SSH into selected service
    run_bash_command_with_output_stream(
        f"{COMPOSE_ORCHESTRATOR} compose -f {COMPOSE_APPS[app]} exec {services[service_idx - 1]} /bin/bash"
    )


def show_compose_app_usage(app: str) -> None:
    # Check if app is running or not
    if not check_compose_app_status(app):
        print(f"App {app} is not running...")
        return

    run_bash_command_with_output_stream(
        f"{COMPOSE_ORCHESTRATOR} compose -f {COMPOSE_APPS[app]} stats --no-stream"
    )


def check_compose_app_status(app: str) -> bool:
    # Check if Docker daemon is running
    if not check_docker_daemon_running():
        return False

    # Get Running Containers for app
    rc, running_containers = run_bash_command(
        f"{COMPOSE_ORCHESTRATOR} compose -f {COMPOSE_APPS[app]} ps --services | sed '/^[[:space:]]*$/d' | wc -l"
    )

    # If any of the commands failed
    if rc != 0:
        return False

    # If no container running
    if running_containers.strip() == "0":
        return False

    # If all checks passed, app is running
    return True


def show_compose_app_status(app: str) -> None:
    # Caputalize First Letter of App for better output
    app_name = app[0].upper() + app[1:]

    # Check Status
    status = check_compose_app_status(app)

    if status:
        print(f"{app_name} is running ...")
        return

    print(f"{app_name} is not running ...")


def provide_connectivity_info(app: str) -> None:
    rc, json_config = run_bash_command(
        f"{COMPOSE_ORCHESTRATOR} compose -f {COMPOSE_APPS[app]} config --format json"
    )

    # Check if command was successful
    if rc != 0:
        print(f"Failed to get connectivity info for app {app} ...")
        print(json_config)
        return

    # Get Published ports per service from JSON config
    app_config = json.loads(json_config)
    configured_services = app_config.get("services", {})
    services_with_ports = {
        name: [
            port.get("published")
            for port in details.get("ports", [])
            if "published" in port
        ]
        for name, details in configured_services.items()
        if "ports" in details
    }

    # Remove any services with unpublished or empty port
    services_with_ports = {
        name: ports for name, ports in services_with_ports.items() if len(ports) > 0
    }

    # Check if any port configured for connectivity, otherwise return
    if len(services_with_ports) == 0:
        print(f"No connection port configured for {app} ...")
        print(
            f"You can still use {app} ssh to enter a runnig container and run commands ..."
        )
        return

    print(f"Connection Info for {app} ...")

    # Show Header
    print("-" * 80)
    print(f"| {'SERVICE':<37}| {'URLs':<38}|")
    print("-" * 80)
    for service, ports in services_with_ports.items():
        # Format the Service name to be more user friendly
        service_name_parts: list[str] = [
            part for part in service.replace("_", "-").split("-") if part.strip() != ""
        ]

        service_name = " ".join([part.capitalize() for part in service_name_parts])
        for idx, port in enumerate(ports):
            service_url = f"localhost:{port}"
            if idx == 0:
                print(f"| {service_name:<37}| {service_url:<38}|")
            else:
                print(f"| {'':<37}| {service_url:<38}|")

        print("-" * 80)

    # At the end show message if app is not running
    if not check_compose_app_status(app):
        print(f"Note: {app} is not running. Start the app to access...")
        return


def get_list_of_all_running_apps() -> list[str]:
    # No app will be running if Docker daemon is not running
    if not check_docker_daemon_running():
        return []

    # List Compose running apps
    rc, running_apps_list = run_bash_command(
        f"{COMPOSE_ORCHESTRATOR} compose ls --format json"
    )

    # Check if any app is running
    if rc != 0 or running_apps_list.strip() == "":
        return []

    running_apps_detail: list[dict[str, str]] = json.loads(running_apps_list.strip())

    return [
        app.get("ConfigFiles", "")
        .replace(str(APP_YAML_PATH), "")
        .replace(".yml", "")
        .replace(os.sep, "")
        for app in running_apps_detail
        if app.get("ConfigFiles", "") != ""
    ]


def show_running_apps() -> None:
    running_apps = get_list_of_all_running_apps()
    if len(running_apps) == 0:
        print("No apps are running ...")
        return

    # Show Running apps list
    print(
        "",
        "Following apps are up - ",
        "\n".join(list(map(lambda x: f" > {x}", running_apps))),
        sep="\n",
    )


def stop_all_running_apps() -> None:
    running_apps = get_list_of_all_running_apps()
    if len(running_apps) == 0:
        print("No apps are running ...")
        return

    # Stop and put all apps down
    for app in running_apps:
        stop_compose_app(app)


def select_and_stop_app() -> None:
    running_apps = get_list_of_all_running_apps()
    if len(running_apps) == 0:
        print("No apps are running ...")
        return

    # Provide list of apps to stop
    print("")
    for idx, app in enumerate(running_apps):
        print(f"[ {idx + 1} ] {app}")

    option = input("\nSelect an app you wish to stop ... ")

    # Validate User selection
    try:
        option = int(option)
    except ValueError:
        print("Invalid Selection ...")
        return

    if option < 1 or option > len(running_apps):
        print("Invalid Selection ...")
        return

    # Stop selected App
    stop_compose_app(running_apps[option - 1])


def run_app_extra_action(app: str, action: str, extra_args: str) -> None:
    # Check if app is running or not
    if not check_compose_app_status(app):
        print(f"App {app} is not running...")
        return

    # Run extra action
    action_detail = EXTRA_ACTION.get(action)

    if action_detail is None:
        return

    # Get Service name and command
    service = action_detail.get("service")
    action_cmd = action_detail.get("command")

    # If Service name of command not found, return
    if service is None or action_cmd is None:
        return

    # Fill Extra args in command
    action_cmd = action_cmd.replace("{##}", extra_args)

    # Run command on service
    run_bash_command_with_output_stream(
        f"{COMPOSE_ORCHESTRATOR} compose -f {COMPOSE_APPS[app]} exec {service} {action_cmd}"
    )


def run_app_action(app: str, action: str, extra_args: str) -> None:
    # Help Action
    if action == "--help":
        show_compose_app_help(app)

    # Action to Start Compose App
    elif action == "start":
        start_compose_app(app)

    # Action to Stop Compose App
    elif action == "stop":
        stop_compose_app(app)

    # Action to Restart Compose App
    elif action == "restart":
        restart_compose_app(app)

    # Action to Show Memory and CPU Stats of Compose App
    elif action == "top":
        show_compose_app_usage(app)

    # Action to Show Logs of Compose App
    elif action == "log":
        show_compose_app_logs(app)

    # SSH into one of the running containers of the Compose App
    elif action == "ssh":
        ssh_into_compose_app_container(app)

    # Check Status of Compose App
    elif action == "status":
        show_compose_app_status(app)

    # Provide Connectivity Info of Compose App
    elif action == "connect":
        provide_connectivity_info(app)

    # Run extra actions
    elif action in EXTRA_ACTION.keys():
        run_app_extra_action(app, action, extra_args)


def run_compose_runner_action(app: str) -> None:
    # Handle Compose Runner Commands instead of App Actions
    if app == "--help":
        show_compose_runner_help()

    elif app == "--list-all":
        print(f"Available Apps are [ {', '.join(COMPOSE_APPS.keys())} ]")

    elif app == "--running":
        show_running_apps()

    elif app == "--stop-all":
        stop_all_running_apps()

    elif app == "--stop":
        select_and_stop_app()


def main():
    # Check if App is Provided
    if len(sys.argv) < 2:
        print("Missing App Name ...")
        show_compose_runner_help()
        sys.exit(1)

    # Check if App is Valid
    APP_NAME = sys.argv[1]
    if APP_NAME not in COMPOSE_APPS_AND_COMMANDS:
        print(f"App '{APP_NAME}' is not supported ...")
        show_compose_runner_help()
        sys.exit(1)

    # Handle Special Runner Commands
    if APP_NAME in COMPOSE_RUNNER_COMMANDS.keys():
        run_compose_runner_action(APP_NAME)
        sys.exit(0)

    # Check if Action is Provided
    if len(sys.argv) < 3:
        print(f"Missing Action for App {APP_NAME} ...")
        show_compose_app_help(APP_NAME)
        sys.exit(1)

    # Build Extra action for app
    build_extra_actions_for_app(APP_NAME)

    # Check if Action is valid
    ACTION_NAME = sys.argv[2]
    if ACTION_NAME not in list(DEFAULT_ACTION.keys()) + list(EXTRA_ACTION.keys()):
        print(f"Invalid Action for App {APP_NAME} ...")
        show_compose_app_help(APP_NAME)
        sys.exit(1)

    # Capture any Extra Args for the application
    EXTRA_ARGS = " ".join(sys.argv[3:]) if len(sys.argv) > 3 else ""

    # Run the App Action
    run_app_action(APP_NAME, ACTION_NAME, EXTRA_ARGS)


if __name__ == "__main__":
    main()
