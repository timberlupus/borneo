# Borneo Hardware - AI Coding Guidelines

## Overview

Borneo Hardware contains PCB designs for ESP32-based aquarium LED controllers, certified by OSHWA.

## Technology Stack

- **EDA Software**: Horizon EDA
- **MCU**: ESP32, ESP32-C3
- **Features**: 6-channel PWM dimming, modular design

## Project Structure

- `3d-models/`: 3D models for enclosures
- Device directories (e.g., `blc06/`, `bdb6mk1/`): PCB designs
- `datasheets/`: Component datasheets

## Development Guidelines

### Key Components

- PCB schematics in Horizon EDA format
- Bill of Materials (BoM)
- Gerber files for manufacturing
- 3D models for cases

### Manufacturing

- Use provided Gerber files
- Follow BoM for components
- Test assembled boards

## Contributing

- Validate designs with Horizon EDA
- Ensure compatibility with firmware
- Document changes in schematics