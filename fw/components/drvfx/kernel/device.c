#include <string.h>

#include <esp_log.h>

#include "drvfx/drvfx.h"

extern const struct drvfx_device* _drvfx_device_start;
extern const struct drvfx_device* _drvfx_device_end;


bool drvfx_device_is_ready(const struct drvfx_device *dev)
{
	/*
	 * if an invalid device pointer is passed as argument, this call
	 * reports the `device` as not ready for usage.
	 */
	if (dev == NULL) {
		return false;
	}

	return dev->state->initialized && (dev->state->init_res == 0);
}


const struct drvfx_device *drvfx_device_get_binding(const char *name)
{
	const struct drvfx_device *dev;

	/* A null string identifies no device.  So does an empty
	 * string.
	 */
	if ((name == NULL) || (name[0] == '\0')) {
		return NULL;
	}

	/* Split the search into two loops: in the common scenario, where
	 * device names are stored in ROM (and are referenced by the user
	 * with CONFIG_* macros), only cheap pointer comparisons will be
	 * performed. Reserve string comparisons for a fallback.
	 */
	for (dev = _drvfx_device_start; dev != _drvfx_device_end; dev++) {
		if (drvfx_device_is_ready(dev) && (dev->name == name)) {
			return dev;
		}
	}

	for (dev = _drvfx_device_start; dev != _drvfx_device_end; dev++) {
		if (drvfx_device_is_ready(dev) && (strcmp(name, dev->name) == 0)) {
			return dev;
		}
	}

	return NULL;
}

size_t drvfx_device_get_all_static(const struct drvfx_device** devices)
{
    *devices = _drvfx_device_start;
    return _drvfx_device_end - _drvfx_device_start;
}
