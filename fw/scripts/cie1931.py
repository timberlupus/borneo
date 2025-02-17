PWM_DUTY_MAX = 1023

def cie1931_adjusted(L):
    """Adjusted CIE 1931 brightness formula."""
    L = L * PWM_DUTY_MAX  # Scale perceived brightness to the range 0-PWM_DUTY_MAX.
    if L <= 8:
        V = L / 903.3
    else:
        V = ((L + 16.0) / 119.0) ** 3
    return V / 0.926  # Normalize so the maximum value is 1.

# Generate lookup table (perceived brightness 0-PWM_DUTY_MAX).
table_size = PWM_DUTY_MAX + 1  # Number of entries in the table.
lookup_table = []
for i in range(table_size):
    perceptual_brightness = i / (table_size - 1)  # Normalize to the range 0-1.
    linear_brightness = cie1931_adjusted(perceptual_brightness)
    pwm_duty = int(linear_brightness * PWM_DUTY_MAX)  # Map to an 10-bit PWM duty cycle (0-PWM_DUTY_MAX).
    lookup_table.append(pwm_duty)

# Print the lookup table.
print(f"const uint16_t cie1931_table[{table_size}] = {{")
print(", ".join(map(str, lookup_table)))
print("};")

