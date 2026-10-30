#include <assert.h>
#include <stdio.h>
#include "KBRCSignature.h"

static unsigned assertions;
static void expect(int condition) {
    ++assertions;
    assert(condition);
}

int main(void) {
    expect(KBRCSignatureMatches(3, "v", "@", ":", "d", "d"));
    expect(KBRCSignatureMatches(3, "v", "@", ":", "f", "f"));
    expect(!KBRCSignatureMatches(0, "v", "@", ":", "d", "d"));
    expect(!KBRCSignatureMatches(2, "v", "@", ":", "d", "d"));
    expect(!KBRCSignatureMatches(4, "v", "@", ":", "d", "d"));
    expect(!KBRCSignatureMatches(3, "@", "@", ":", "d", "d"));
    expect(!KBRCSignatureMatches(3, "i", "@", ":", "d", "d"));
    expect(!KBRCSignatureMatches(3, "v", "#", ":", "d", "d"));
    expect(!KBRCSignatureMatches(3, "v", "@", "@", "d", "d"));
    expect(!KBRCSignatureMatches(3, "v", "@", ":", "f", "d"));
    expect(!KBRCSignatureMatches(3, "v", "@", ":", "@", "d"));
    expect(!KBRCSignatureMatches(3, "v", "@", ":", "{CGPoint=dd}", "d"));
    expect(!KBRCSignatureMatches(3, "v", "@", ":", "rd", "d"));
    expect(!KBRCSignatureMatches(3, NULL, "@", ":", "d", "d"));
    expect(!KBRCSignatureMatches(3, "v", NULL, ":", "d", "d"));
    expect(!KBRCSignatureMatches(3, "v", "@", NULL, "d", "d"));
    expect(!KBRCSignatureMatches(3, "v", "@", ":", NULL, "d"));
    expect(!KBRCSignatureMatches(3, "v", "@", ":", "d", NULL));
    expect(!KBRCSignatureMatches(3, "v", "@", ":", "", "d"));
    expect(!KBRCSignatureMatches(3, "v", "@", ":", "d", ""));
    printf("KBRC_ABI_PASS assertions=%u NOT_IOS_RUNTIME\n", assertions);
    return 0;
}
