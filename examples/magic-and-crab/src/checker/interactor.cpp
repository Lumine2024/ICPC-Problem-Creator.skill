#include "testlib.h"
#include <bits/stdc++.h>

using namespace std;

int main(int argc, char* argv[]) {
    registerInteraction(argc, argv);

    long long hidden = inf.readLong(2LL, 1000000000000000000LL, "x");
    inf.readEoln();
    inf.readEof();

    int queries = 0;
    while (true) {
        char type = ouf.readChar();
        if (type == '?') {
            if (queries == 20) {
                quitf(_wa, "too many queries");
            }
            ouf.readSpace();
            long long y = ouf.readLong(2LL, 100LL, "y");
            ouf.readEoln();
            cout << std::gcd(hidden, y) << endl;
            cout.flush();
            ++queries;
            continue;
        }

        if (type == '!') {
            ouf.readSpace();
            long long z = ouf.readLong(2LL, 100LL, "z");
            ouf.readEoln();
            ouf.readEof();
            if (std::gcd(hidden, z) != 1) {
                quitf(_wa, "answer %lld is not coprime with hidden value %lld", z, hidden);
            }
            quitf(_ok, "accepted with %d queries", queries);
        }

        quitf(_pe, "unknown action %c", type);
    }
}
