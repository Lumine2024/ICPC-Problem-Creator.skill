#include <bits/stdc++.h>

using namespace std;

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    const vector<int> primes = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29};
    for (int p : primes) {
        cout << "? " << p << endl;
        int g;
        cin >> g;
        if (g == 1) {
            cout << "! " << p << endl;
            return 0;
        }
    }

    cout << "! 2" << endl;
    return 0;
}
