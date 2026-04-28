#include <bits/stdc++.h>

using namespace std;

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    for (int prime : {2, 3, 5, 7, 11, 13, 17}) {
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
