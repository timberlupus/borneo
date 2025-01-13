def cie1931_adjusted(L):
    """Adjusted CIE 1931 brightness formula."""
    L = L * 100.0  # Scale perceived brightness to the range 0-100.
    if L <= 8:
        V = L / 903.3
    else:
        V = ((L + 16.0) / 119.0) ** 3
    return V / 0.926  # Normalize so the maximum value is 1.

# Generate lookup table (perceived brightness 0-100).
table_size = 101  # Number of entries in the table.
lookup_table = []
for i in range(table_size):
    perceptual_brightness = i / (table_size - 1)  # Normalize to the range 0-1.
    linear_brightness = cie1931_adjusted(perceptual_brightness)
    pwm_duty = int(linear_brightness * 255)  # Map to an 8-bit PWM duty cycle (0-255).
    lookup_table.append(pwm_duty)

# Print the lookup table.
print("const uint8_t cie1931_table[101] = {")
print(", ".join(map(str, lookup_table)))
print("};")
