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

    long long n = 0;
    if (type == "sample") {
        n = 5;
    } else if (type == "min") {
        n = 0;
    } else if (type == "random-small") {
        n = rnd.next(0LL, 1000LL);
    } else if (type == "random-large") {
        n = rnd.next(1000000LL, 1000000000LL);
    } else if (type == "max") {
        n = 1000000000LL;
    } else {
        cerr << "Unknown case type: " << type << '\n';
        return 2;
    }

    cout << n << '\n';
    return 0;
}
