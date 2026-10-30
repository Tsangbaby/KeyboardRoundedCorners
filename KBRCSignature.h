#ifndef KBRC_SIGNATURE_H
#define KBRC_SIGNATURE_H

#include <stdbool.h>
#include <string.h>

/* Strict, allocation-free comparison; runtime metadata is read by Tweak.xm. */
static inline bool KBRCSignatureMatches(unsigned int argumentCount,
                                        const char *returnType,
                                        const char *receiverType,
                                        const char *selectorType,
                                        const char *radiusType,
                                        const char *expectedRadiusType) {
    return argumentCount == 3 &&
           returnType && strcmp(returnType, "v") == 0 &&
           receiverType && strcmp(receiverType, "@") == 0 &&
           selectorType && strcmp(selectorType, ":") == 0 &&
           radiusType && expectedRadiusType && expectedRadiusType[0] != '\0' &&
           strcmp(radiusType, expectedRadiusType) == 0;
}

#endif
