#include "testlib.h"
#include <bits/stdc++.h>

using namespace std;

namespace {

const vector<long long> PRIMES = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 97};
const long long LIM = 1000000000000000000LL;
const long long PRIMORIAL10 = 6469693230LL;
const long long PRIMORIAL15 = 614889782588491410LL;

void print_case(long long x) {
    cout << x << '\n';
}

long long safe_mul(long long a, long long b) {
    if (a > LIM / b) {
        return LIM + 1;
    }
    return a * b;
}

long long make_smooth() {
    vector<long long> primes = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47};
    for (int i = int(primes.size()) - 1; i > 0; --i) {
        int j = rnd.next(0, i);
        swap(primes[i], primes[j]);
    }
    long long x = 1;
    for (long long p : primes) {
        if (rnd.next(0, 1) == 0) {
            continue;
        }
        while (true) {
            long long next = safe_mul(x, p);
            if (next > LIM || rnd.next(0, 3) == 0) {
                break;
            }
            x = next;
        }
    }
    if (x < 2) {
        x = 2;
    }
    return x;
}

}  // namespace

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
    } else if (type == "prime") {
        x = PRIMES[rnd.next(0, int(PRIMES.size()) - 1)];
    } else if (type == "primorial10") {
        x = PRIMORIAL10;
    } else if (type == "primorial15") {
        x = PRIMORIAL15;
    } else if (type == "multiple97") {
        long long limit = LIM / 97;
        x = 97 * rnd.next(2LL, limit);
    } else if (type == "smooth") {
        x = make_smooth();
    } else if (type == "power2") {
        int exp = rnd.next(1, 59);
        x = 1LL << exp;
        if (x < 2) {
            x = 2;
        }
    } else if (type == "random-small") {
        x = rnd.next(2LL, 1000000LL);
    } else if (type == "random-large") {
        x = rnd.next(2LL, LIM);
    } else if (type == "near-max") {
        x = rnd.next(LIM - 1000000LL, LIM);
    } else if (type == "special") {
        if (seed % 2 == 1) {
            x = (PRIMORIAL15 / 47) * 53;
        } else {
            x = PRIMORIAL10 * 97;
        }
    } else {
        cerr << "Unknown case type: " << type << '\n';
        return 2;
    }

    print_case(x);
    return 0;
}
