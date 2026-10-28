#ifndef KBRC_KEY_GEOMETRY_H
#define KBRC_KEY_GEOMETRY_H

#include <math.h>

/* Pure geometry policy shared by the tweak and the host-side test. */
static inline double KBRCKeyCapCornerRadiusForSize(double width, double height) {
    if (!isfinite(width) || !isfinite(height)) return 0.0;

    const double shortEdge = fmin(width, height);
    if (shortEdge < 4.0) return 0.0;

    const double radius = shortEdge * 0.25;
    return fmin(radius, 14.0);
}

#endif
