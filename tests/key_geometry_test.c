#include <assert.h>
#include <math.h>
#include <stdio.h>

#include "../KBRCKeyGeometry.h"

static void expect_close(double actual, double expected) {
    assert(fabs(actual - expected) < 1e-9);
}

int main(void) {
    /* Screenshot-like letter key: ~33 x 42 pt -> 8.25 pt radius. */
    expect_close(KBRCKeyCapCornerRadiusForSize(33.0, 42.0), 8.25);

    /* Wide space bar still uses its short edge, not its full width. */
    expect_close(KBRCKeyCapCornerRadiusForSize(180.0, 42.0), 10.5);

    /* Large key-like views are bounded. */
    expect_close(KBRCKeyCapCornerRadiusForSize(120.0, 100.0), 14.0);

    /* Reject zero/tiny/negative/invalid geometry. */
    expect_close(KBRCKeyCapCornerRadiusForSize(3.99, 42.0), 0.0);
    expect_close(KBRCKeyCapCornerRadiusForSize(0.0, 42.0), 0.0);
    expect_close(KBRCKeyCapCornerRadiusForSize(-2.0, 42.0), 0.0);
    expect_close(KBRCKeyCapCornerRadiusForSize(NAN, 42.0), 0.0);
    expect_close(KBRCKeyCapCornerRadiusForSize(INFINITY, 42.0), 0.0);

    puts("PASS: keycap corner-radius geometry (9 checks)");
    return 0;
}
