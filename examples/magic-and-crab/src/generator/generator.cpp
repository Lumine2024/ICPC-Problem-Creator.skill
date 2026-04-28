#include "testlib.h"
#include <bits/stdc++.h>

using namespace std;

int main(int argc, char* argv[]) {
    registerGen(argc, argv, 1);
    if (argc != 3) {
        cerr << "Usage: generator <type> <seed>\n";
        return 1;
    }

    string type = argv[1];
    long long seed = atoll(argv[2]);
    rnd.setSeed(seed);

    long long x = 2;
    if (type == "sample") {
        x = 12;
    } else if (type == "min") {
        x = 2;
    } else if (type == "random-small") {
        x = rnd.next(2LL, 1000000LL);
    } else if (type == "random-large") {
        x = rnd.next(1000000000000LL, 1000000000000000000LL);
    } else if (type == "max") {
        x = 1000000000000000000LL;
    } else {
        cerr << "Unknown case type: " << type << '\n';
        return 2;
    }

    cout << x << '\n';
    return 0;
}
