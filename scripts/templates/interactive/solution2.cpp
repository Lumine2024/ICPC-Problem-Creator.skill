#include <bits/stdc++.h>

using namespace std;

int main() {
    vector<int> primes = {2, 3, 5, 7, 11, 13, 17, 19};
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

    cout << "! 97\n";
    cout.flush();
    return 0;
}
