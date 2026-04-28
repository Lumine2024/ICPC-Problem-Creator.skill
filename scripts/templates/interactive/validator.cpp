#include "testlib.h"

int main(int argc, char* argv[]) {
    registerValidation(argc, argv);
    inf.readLong(2LL, 100LL, "hidden");
    inf.readEoln();
    inf.readEof();
    return 0;
}
