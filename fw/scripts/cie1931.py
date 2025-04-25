import math
import numpy as np
import datetime


def generate_cie1931_lut(size):
    """Generate CIE 1931 brightness curve lookup table"""
    lut = []
    for i in range(size):
        x = i / (size - 1)  # Normalize to 0-1
        if x <= 0.008856:
            y = x * 903.3
        else:
            y = 116 * (x ** (1/3)) - 16
        y = y / 100  # Normalize to 0-1
        lut.append(round(y * 1023))  # Scale to 0-1023
    return lut


def generate_logarithmic_lut(size):
    """Generate logarithmic dimming curve lookup table"""
    lut = []
    for i in range(size):
        x = i / (size - 1)  # Normalize to 0-1
        # Use logarithmic curve with offset to avoid log(0)
        # Divided by 2 to normalize max value to ~1
        y = math.log10(1 + x * 99) / 2
        lut.append(round(y * 1023))  # Scale to 0-1023
    return lut


def generate_lut_header(lut_size):
    """Generate C header file containing both LUTs"""
    cie_lut = generate_cie1931_lut(lut_size)
    log_lut = generate_logarithmic_lut(lut_size)

    header = f"""// Auto-generated brightness lookup tables
// Generation time: {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
// LUT size: {lut_size}

#include <stdlib.h>
#include <stdbool.h>
#include <time.h>

// CIE 1931 brightness curve lookup table (perceptual uniform)
const led_duty_t LED_CORLUT_CIE1931[LED_BRIGHTNESS_MAX + 1] = {{
    {', '.join(map(str, cie_lut))},
}};

// Logarithmic dimming curve lookup table
const led_duty_t LED_CORLUT_LOG[LED_BRIGHTNESS_MAX + 1] = {{
    {', '.join(map(str, log_lut))},
}};

"""
    return header


if __name__ == "__main__":
    # User-configurable LUT size
    lut_size = 1001  # Can be adjusted as needed

    # Generate header file content
    header_content = generate_lut_header(lut_size)

    # Write to file
    with open("brightness_lut.h", "w") as f:
        f.write(header_content)

    print("Lookup tables generated in brightness_lut.h")
