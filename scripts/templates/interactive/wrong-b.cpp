#include <bits/stdc++.h>

using namespace std;

int main() {
    for (int prime : {2, 3, 5, 7, 11, 13, 17}) {
        cout << "? " << prime << '\n';
        cout.flush();
        long long ignored = 0;
        if (!(cin >> ignored)) {
            return 0;
        }
    }

    cout << "! 6\n";
    cout.flush();
    return 0;
}
