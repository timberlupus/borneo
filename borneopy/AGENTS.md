# BorneoPy - AI Coding Guidelines

## Overview

BorneoPy is a Python client library for controlling Borneo-IoT devices using CoAP protocol. It provides APIs for device control, firmware updates, and information queries.

## Technology Stack

- **Language**: Python 3.10+
- **Protocol**: CoAP (Constrained Application Protocol)
- **Key Libraries**: asyncio, aiocoap

## Project Structure

- `borneo/`: Main package
  - `__init__.py`: Package initialization
  - `device.py`: Base device classes
  - `esptouch.py`: ESP Touch provisioning
  - `lyfi.py`: LyFi device client
- `examples/`: Usage examples
- `requirements.txt`: Dependencies
- `setup.py`: Package setup

## Development Guidelines

### Coding Standards

- Follow PEP 8 style guide
- Use type hints for function parameters and return values
- Write asynchronous code using asyncio
- Handle exceptions appropriately

### Dependencies

Install dependencies:
```bash
pip install -r requirements.txt
```

### Building and Testing

- Use `setup.py` for packaging
- Run tests with `pytest` (if available)
- Validate with `python -m py_compile` for syntax

### Key Classes

- `LyfiCoapClient`: Main client for LyFi devices
- Supports operations: power control, info queries, OTA updates

### Examples

See `examples/` directory for usage patterns.

## Contributing

- Add type hints and docstrings
- Write unit tests for new features
- Update examples for API changes