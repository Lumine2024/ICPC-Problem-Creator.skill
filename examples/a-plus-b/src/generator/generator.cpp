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

    long long a = 0, b = 0;
    if (type == "sample") {
        a = 1;
        b = 2;
    } else if (type == "zero") {
        a = 0;
        b = 0;
    } else if (type == "small") {
        a = rnd.next(-1000LL, 1000LL);
        b = rnd.next(-1000LL, 1000LL);
    } else if (type == "negative") {
        a = -rnd.next(1LL, 1000000000LL);
        b = -rnd.next(1LL, 1000000000LL);
    } else if (type == "overflow") {
        a = 1000000000000000000LL;
        b = 1000000000000000000LL;
    } else if (type == "mixed") {
        a = -1000000000000000000LL;
        b = rnd.next(999999999999999900LL, 1000000000000000000LL);
    } else if (type == "max") {
        a = rnd.next(-1000000000000000000LL, 1000000000000000000LL);
        b = rnd.next(-1000000000000000000LL, 1000000000000000000LL);
    } else {
        cerr << "Unknown case type: " << type << '\n';
        return 2;
    }

    cout << a << ' ' << b << '\n';
    return 0;
}
