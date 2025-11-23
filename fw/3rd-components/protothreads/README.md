
protothreads — ESP-IDF component
================================

Overview
--------

This folder contains a port of the Protothreads library packaged as an ESP-IDF component. It provides lightweight, stackless threads (protothreads) suitable for small embedded tasks and cooperative multitasking.

Installation
------------

- Copy this component directory into your project's `components/` folder, or add its path to your project's CMake with `EXTRA_COMPONENT_DIRS`.
- The component is compatible with the standard ESP-IDF build system and should be discovered automatically when placed under `components/`.

Usage
-----

- Public headers are provided under `include/` and `port/include/`. Include the headers from your source files as needed.
- Typical usage pattern follows the original Protothreads API (e.g. `PT_BEGIN`, `PT_END`, `PT_WAIT_UNTIL`). See the example files in `pt-1.4/` for reference.

Files
-----

- `pt-1.4/` — Original Protothreads source and examples.
- `port/` — ESP-specific port and header locations.
- `include/` — Public headers for use by application code.

License and Attribution
-----------------------

This component contains code derived from the Protothreads project. See the sources under `pt-1.4/` for the original license and attribution information.

If you need a usage example added to an ESP-IDF project (CMake snippet or a small demo), open an issue or request in this repository and we can add one.

