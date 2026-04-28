#include "testlib.h"
#include <bits/stdc++.h>

using namespace std;

int main(int argc, char* argv[]) {
    registerInteraction(argc, argv);

    long long hidden = inf.readLong();
    const vector<int> primes = {2, 3, 5, 7, 11, 13, 17};

    for (int step = 0; step < 7; ++step) {
        char type = ouf.readChar();
        if (type == '?') {
            long long y = ouf.readLong(2LL, 100LL, "y");
            ouf.readEoln();
            cout << std::gcd(hidden, y) << endl;
            cout.flush();
            continue;
        }

        if (type == '!') {
            long long z = ouf.readLong(2LL, 100LL, "z");
            ouf.readEoln();
            if (std::gcd(hidden, z) != 1) {
                quitf(_wa, "answer %lld is not coprime with hidden value %lld", z, hidden);
            }
            quitf(_ok, "accepted");
        }

        quitf(_pe, "unknown action %c", type);
    }

    quitf(_wa, "too many queries");
}
