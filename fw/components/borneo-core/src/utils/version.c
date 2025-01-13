#include <stdio.h>

#include <borneo/utils/version.h>

int version_parse(struct version* ver, const char* src)
{
    int rc = sscanf(src, "%hu.%hu.%lu", &ver->major, &ver->minor, &ver->patch);
    if (rc == EOF) {
        return -EOF;
    }

    return 0;
}

int version_compare(const struct version* lhs, const struct version* rhs)
{
    if (lhs->major == rhs->major) {

        if (lhs->minor == rhs->minor) {

            if (lhs->patch == rhs->patch) {
                return 0;
            }
            else {
                return (int)lhs->patch - (int)rhs->patch;
            }
        }
        else {
            return (int)lhs->minor - (int)rhs->minor;
        }
    }
    else {

        return (int)lhs->major - (int)rhs->major;
    }
}