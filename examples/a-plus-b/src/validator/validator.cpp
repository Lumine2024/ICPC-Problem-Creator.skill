#include "testlib.h"

int main(int argc, char* argv[]) {
    registerValidation(argc, argv);
    inf.readLong(-1000000000000000000LL, 1000000000000000000LL, "a");
    inf.readSpace();
    inf.readLong(-1000000000000000000LL, 1000000000000000000LL, "b");
    inf.readEoln();
    inf.readEof();
    return 0;
}
