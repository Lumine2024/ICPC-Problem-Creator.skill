#include "testlib.h"

int main(int argc, char* argv[]) {
    registerValidation(argc, argv);
    inf.readLong(0LL, 1000000000LL, "n");
    inf.readEoln();
    inf.readEof();
    return 0;
}
