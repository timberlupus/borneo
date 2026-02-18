"""Command-line entry point for the Borneo library.

Commands are packaged as `Command` instances to make adding new
sub-commands straightforward and testable.
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import sys
from dataclasses import dataclass
from typing import Any, Awaitable, Callable, Optional, Sequence, cast
import json
import base64
import inspect

from borneo.lyfi import LyfiCoapClient

from importlib.metadata import version as _get_version

# zeroconf is a required dependency (declared in pyproject.toml)
from zeroconf import IPVersion, ServiceStateChange
from zeroconf.asyncio import (
    AsyncServiceBrowser,
    AsyncServiceInfo,
    AsyncZeroconf,
    AsyncZeroconfServiceTypes,
)

# aiocoap is a required dependency
from aiocoap import Context

# aiofiles and cbor2 are required dependencies for OTA
import aiofiles  # type: ignore
import cbor2  # type: ignore


def _version() -> str:
    if _get_version is None:
        return "borneoiot (unknown)"
    try:
        return _get_version("borneoiot")
    except Exception:
        return "borneoiot (unknown)"


@dataclass
class Command:
    """Lightweight container for a CLI command.

    name: command name shown on the command line (positional)
    help: short help text
    add_arguments: optional callable to add argparse arguments for the command
    handler: async or sync callable receiving parsed `argparse.Namespace`
    """

    name: str
    help: str
    add_arguments: Optional[Callable[[argparse.ArgumentParser], None]] = None
    handler: Callable[[argparse.Namespace], Awaitable[int | None] | int | None] = lambda _: 0


@dataclass
class CoapCommand(Command):
    """Command subclass for CoAP-related commands.

    Marker class used to indicate the command needs a CoAP `host` option.
    The `-h/--host` option is provided only at the top-level parser to avoid
    duplicate help entries; subparsers should not re-declare it.
    """
    def __post_init__(self):
        # preserve original add_arguments behaviour but do NOT inject `host` on
        # the subparser to avoid duplicate `-h/--host` entries in help output.
        original_add = self.add_arguments
        def _add(parser: argparse.ArgumentParser):
            if original_add:
                original_add(parser)
        self.add_arguments = _add


_COMPATIBLES = {
    'bst,borneo-lyfi': LyfiCoapClient
}

# --- built-in/example commands ------------------------------------------------

# example commands removed; use `mdns` for discovery


# --- mdns command (service discovery) --------------------------------------

_PENDING_TASKS: set[asyncio.Task] = set()


def _mdns_on_service_state_change(
    zeroconf, service_type: str, name: str, state_change
) -> None:
    # only act on newly added services
    print(f"Service {name} of type {service_type} state changed: {state_change}")
    if state_change is not None and str(state_change).lower() != "servicestatechange.added":
        # use conservative check (some zeroconf versions expose enum differently)
        return

    task = asyncio.ensure_future(_mdns_display_service_info(zeroconf, service_type, name))
    _PENDING_TASKS.add(task)
    task.add_done_callback(_PENDING_TASKS.discard)


async def _mdns_display_service_info(zeroconf, service_type: str, name: str) -> None:
    """Query and print a service's details (async)."""
    info = AsyncServiceInfo(service_type, name)
    await info.async_request(zeroconf, 3000)

    if info:
        addresses = [f"{addr}:{cast(int, info.port)}" for addr in info.parsed_scoped_addresses()]
        print("  Name: %s" % name)
        print("  Addresses: %s" % ", ".join(addresses))
        print("  Weight: %d, priority: %d" % (info.weight, info.priority))
        print(f"  Server: {info.server}")
        if info.properties:
            print("  Properties are:")
            for key, value in info.properties.items():
                print(f"    {key!r}: {value!r}")
        else:
            print("  No properties")
    else:
        print("  No info")
    print()


async def _mdns_handler(args: argparse.Namespace) -> int:
    """Discover and print mDNS/zeroconf services for a given duration."""

    if getattr(args, "debug", False):
        logging.getLogger("zeroconf").setLevel(logging.DEBUG)

    if getattr(args, "v6", False):
        ip_version = IPVersion.All
    elif getattr(args, "v6_only", False):
        ip_version = IPVersion.V6Only
    else:
        ip_version = IPVersion.V4Only

    aiozc = AsyncZeroconf(ip_version=ip_version)

    services = ["_borneo._udp.local."]
    if getattr(args, "find", False):
        services = list(await AsyncZeroconfServiceTypes.async_find(aiozc=aiozc, ip_version=ip_version))

    print(f"\nBrowsing {services} service(s) for {args.timeout} second(s)...\n")

    aiobrowser = AsyncServiceBrowser(aiozc.zeroconf, services, handlers=[_mdns_on_service_state_change])

    try:
        await asyncio.sleep(max(0, int(args.timeout)))
    except asyncio.CancelledError:
        pass
    finally:
        await aiobrowser.async_cancel()
        await aiozc.async_close()

    return 0


def _mdns_add_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("-t", "--timeout", type=int, default=5, help="discovery duration in seconds (default: 5)")
    parser.add_argument("--find", action="store_true", help="browse all available service types")
    parser.add_argument("--debug", action="store_true", help="enable debug logging for zeroconf")
    version_group = parser.add_mutually_exclusive_group()
    version_group.add_argument("--v6", dest="v6", action="store_true", help="use IPv4+IPv6 discovery")
    version_group.add_argument("--v6-only", dest="v6_only", action="store_true", help="use IPv6-only discovery")


def _lota_add_arguments(parser: argparse.ArgumentParser) -> None:
    """Arguments for local OTA over CoAP (`lota`).

    Note: `-h/--host` option is provided by `CoapCommand`.
    """
    parser.add_argument("fw_path", help="Path to the firmware `.bin` file to upload")
    parser.add_argument("--block-size", type=int, default=512, choices=[16, 32, 64, 128, 256, 512],
                        help="CoAP block size in bytes (default: 512)")
    parser.add_argument("--status-only", action="store_true", help="only query OTA status and exit without uploading")


async def _lota_handler(args: argparse.Namespace) -> int:
    """CLI wrapper that delegates OTA work to `borneo.coap_ota`.

    The library module performs network operations and uses logging;
    the CLI prints user-facing messages based on returned results.
    """

    from borneo.coap_ota import CoAPFirmwareUpdater

    # `host` is added by CoapCommand
    updater = CoAPFirmwareUpdater(args.host, args.fw_path, args.block_size)

    # quick status check
    try:
        context = await Context.create_client_context()
    except Exception as e:
        print(f"Failed to create CoAP client context: {e}")
        return 1

    try:
        status = await updater.check_server_status(context)
    finally:
        try:
            await context.shutdown()
        except Exception:
            pass

    if getattr(args, "status_only", False):
        if status is None:
            print("Status check failed or no response")
            return 1
        print("\nServer status:")
        for k, v in (status.items() if isinstance(status, dict) else []):
            print(f"  {k}: {v}")
        return 0

    if status is None:
        print("Warning: server status check failed or returned non-ready state; proceeding with upload anyway")

    try:
        result = await updater.send_firmware()
    except FileNotFoundError as e:
        print(str(e))
        return 1
    except Exception as e:
        print(f"OTA failed: {e}")
        return 1

    if result.get("success"):
        print("\nFirmware update process completed, device should reboot automatically with new firmware")
        if result.get("sha256"):
            print(f"SHA256: {result['sha256']}")
        if result.get("next_boot") is not None:
            print(f"Next boot partition: {result['next_boot']}")
        return 0

    print("\nFirmware update failed")
    if result.get("error"):
        print(result.get("error"))
    return 1


async def _get_handler(args: argparse.Namespace) -> int:
    """Handle `bocli get <what> <url>` — reflectively call `get_<what>` on `LyfiCoapClient` and print JSON.

    Also supports `--list` to enumerate available `get_...` methods.
    """
    if getattr(args, "list", False):
        # reuse the capabilities printer (returns exit code)
        return await _capabilities_handler(args)

    what = getattr(args, "what", None)
    if not what:
        print("error: missing 'what' argument (e.g. 'color')")
        return 2

    method_name = f"get_{what}"
    if not hasattr(LyfiCoapClient, method_name):
        print(f"error: unknown get target: {what!r} (no method {method_name!r})")
        return 2

    host = getattr(args, "host", None)
    if not host:
        print("error: missing device host (positional 'host')")
        return 2

    try:
        async with LyfiCoapClient(host) as client:
            method = getattr(client, method_name)
            # only allow methods that accept no arguments (bound method signature must be empty)
            sig = inspect.signature(method)
            if len(sig.parameters) != 0:
                print(f"error: {method_name} accepts parameters; only parameter-less `get_...` methods are allowed")
                return 2
            result = await method()
    except Exception as e:
        print(f"error: {e}")
        return 1

    def _json_default(o):
        # bytes -> base64, enums/objects -> value or str
        if isinstance(o, (bytes, bytearray)):
            return base64.b64encode(bytes(o)).decode("ascii")
        if hasattr(o, "value"):
            return getattr(o, "value")
        return str(o)

    print(json.dumps(result, default=_json_default, ensure_ascii=False, indent=2))
    return 0


def _get_add_arguments(parser: argparse.ArgumentParser) -> None:
    """Add arguments for `get` command and support reflective calls to `get_<what>`.

    `-h/--host` option is injected by `CoapCommand` for CoAP targets.
    """
    parser.add_argument("what", nargs="?", help="resource to get (calls method `get_<what>`, e.g. 'color')")
    parser.add_argument("--list", action="store_true", help="list available `get_...` targets on LyfiCoapClient and exit")


def _capabilities_add_arguments(parser: argparse.ArgumentParser) -> None:
    """Add arguments for `capabilities` command."""
    parser.add_argument("--json", action="store_true", help="output JSON")


async def _capabilities_handler(args: argparse.Namespace) -> int:
    """Reflectively enumerate all `get_...` methods on `LyfiCoapClient` and print details.

    Output fields: name (without `get_`), signature (excluding `self`), whether
    the CLI is allowed to call it (parameter-less after binding), and first line
    of the docstring.
    """
    entries = []
    for name in sorted(dir(LyfiCoapClient)):
        if not name.startswith("get_"):
            continue
        attr = getattr(LyfiCoapClient, name)
        if not callable(attr):
            continue
        sig = inspect.signature(attr)
        # exclude `self` from displayed signature
        params = [p for p in sig.parameters.values() if p.name != "self"]
        sig_str = "(" + ", ".join(str(p) for p in params) + ")"
        # allowed for CLI if bound method would accept no parameters
        allowed = len(params) == 0
        doc = (attr.__doc__ or "").strip().splitlines()[0] if (attr.__doc__ or "").strip() else ""
        entries.append({
            "name": name[4:],
            "method": name,
            "signature": sig_str,
            "allowed": allowed,
            "doc": doc,
        })

    if getattr(args, "json", False):
        print(json.dumps(entries, ensure_ascii=False, indent=2))
        return 0

    print("Available get targets (from LyfiCoapClient):")
    for e in entries:
        allowed_mark = "[allowed]" if e["allowed"] else ""
        print(f"  {e['name']:20} {e['signature']:20} {allowed_mark:9}  {e['doc']}")
    return 0


def _factory_reset_add_arguments(parser: argparse.ArgumentParser) -> None:
    """Add arguments for `factory-reset` command."""
    parser.add_argument("-y", "--yes", dest="yes", action="store_true",
                        help="automatic 'yes' to confirmation prompt")


async def _factory_reset_handler(args: argparse.Namespace) -> int:
    """Send a factory reset to the device (clears user data)."""
    host = getattr(args, "host", None)
    if not host:
        print("error: missing device host (positional 'host')")
        return 2

    if not getattr(args, "yes", False):
        resp = input(f"Are you sure you want to factory reset the device at {host}? This will clear ALL user data. (y/N): ")
        if resp.lower() not in ("y", "yes"):
            print("Aborted.")
            return 0

    try:
        async with LyfiCoapClient(host) as client:
            await client.factory_reset()
    except Exception as e:
        print(f"error: {e}")
        return 1

    print("Factory reset command sent; device should clear user data and reboot.")
    return 0


async def _on_handler(args: argparse.Namespace) -> int:
    """Turn the device on (uses `get_on_off` to avoid unnecessary calls)."""
    host = getattr(args, "host", None)
    if not host:
        print("error: missing device host (positional 'host')")
        return 2

    try:
        async with LyfiCoapClient(host) as client:
            current = await client.get_on_off()
            if current:
                print("Device is already ON")
                return 0
            await client.set_on_off(True)
    except Exception as e:
        print(f"error: {e}")
        return 1

    print("Device turned ON")
    return 0


async def _off_handler(args: argparse.Namespace) -> int:
    """Turn the device off (uses `get_on_off` to avoid unnecessary calls)."""
    host = getattr(args, "host", None)
    if not host:
        print("error: missing device host (positional 'host')")
        return 2

    try:
        async with LyfiCoapClient(host) as client:
            current = await client.get_on_off()
            if not current:
                print("Device is already OFF")
                return 0
            await client.set_on_off(False)
    except Exception as e:
        print(f"error: {e}")
        return 1

    print("Device turned OFF")
    return 0


def get_commands() -> list[Command]:
    """Return the available Command objects (extendable by tests)."""
    return [
        CoapCommand(name="lota", help="perform local OTA over CoAP", add_arguments=_lota_add_arguments, handler=_lota_handler),
        Command(name="mdns", help="discover devices via mDNS and print info", add_arguments=_mdns_add_arguments, handler=_mdns_handler),
        Command(name="capabilities", help="list available `get_...` methods on LyfiCoapClient", add_arguments=_capabilities_add_arguments, handler=_capabilities_handler),
        CoapCommand(name="factory-reset", help="perform factory reset (clears user data)", add_arguments=_factory_reset_add_arguments, handler=_factory_reset_handler),
        CoapCommand(name="on", help="turn device on", handler=_on_handler),
        CoapCommand(name="off", help="turn device off", handler=_off_handler),
        CoapCommand(name="get", help="retrieve device resource (e.g. color) and print as JSON (only parameterless get_... methods allowed)", add_arguments=_get_add_arguments, handler=_get_handler),
    ]


# --- CLI entrypoint -----------------------------------------------------------

async def main(argv: Optional[Sequence[str]] = None) -> int:
    """Asynchronous CLI entrypoint.

    Accepts an optional argv (useful for tests). Returns an exit code.
    """
    argv = list(argv) if argv is not None else sys.argv[1:]

    # disable default -h so we can reuse -h for `--host`; keep `--help` only
    parser = argparse.ArgumentParser(prog="bocli", description="Borneo command-line tool", add_help=False)
    parser.add_argument("--help", action="help", help="show this help message and exit")

    # global host for CoAP commands (allow before subcommand)
    parser.add_argument("-h", "--host", dest="host", help="Device base URL for CoAP commands, e.g.: `coap://192.168.1.10`")

    parser.add_argument("-v", "--verbose", action="count", default=0, help="increase verbosity")
    parser.add_argument("-c", "--compatible", default="bst,borneo-lyfi", help="compatibility string (default: 'bst,borneo-lyfi')")
    parser.add_argument("--version", action="version", version=_version())

    subparsers = parser.add_subparsers(dest="command", metavar="<command>", required=True)

    # register commands (create subparsers without -h and provide only --help)
    for cmd in get_commands():
        sub = subparsers.add_parser(cmd.name, help=cmd.help, description=cmd.help, add_help=False)
        # add only --help for subcommands
        sub.add_argument("--help", action="help", help="show this help message and exit")
        if cmd.add_arguments:
            cmd.add_arguments(sub)
        sub.set_defaults(func=cmd.handler)

    args = parser.parse_args(argv)

    handler: Any = getattr(args, "func", None)
    if handler is None:
        parser.print_help()
        return 2

    result = handler(args)
    if asyncio.iscoroutine(result):
        rc = await result
    else:
        rc = result

    return 0 if rc is None else int(rc)


def run() -> None:
    """Synchronous wrapper used by console scripts (runs the async `main`)."""
    rc = asyncio.run(main())
    if rc:
        sys.exit(rc)


if __name__ == "__main__":
    run()
