#include <bits/stdc++.h>

using namespace std;

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    vector<int> primes = {
        2, 3, 5, 7, 11, 13, 17, 19, 23, 29,
        31, 37, 41, 43, 47, 53, 59, 61, 67, 71
    };

    for (int prime : primes) {
        cout << "? " << prime << '\n';
        cout.flush();
        long long g = 0;
        if (!(cin >> g)) {
            return 0;
        }
        if (g == 1) {
            cout << "! " << prime << '\n';
            cout.flush();
            return 0;
        }
    }

    return 0;
}
