#include <bits/stdc++.h>

using namespace std;

int ask(int y) {
    cout << "? " << y << endl;
    int g;
    cin >> g;
    return g;
}

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    vector<int> primes = {53, 47, 43, 41, 37, 31, 29, 23, 19, 17, 13, 11, 7, 5, 3, 2};
    int answer = -1;
    for (int p : primes) {
        if (ask(p) == 1) {
            answer = p;
            break;
        }
    }

    if (answer != -1) {
        cout << "! " << answer << endl;
    } else {
        cout << "! 2" << endl;
    }
    return 0;
}
