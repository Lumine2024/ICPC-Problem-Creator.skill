#include <bits/stdc++.h>

using namespace std;

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    int t = 0;
    cin >> t;
    string line;
    getline(cin, line);
    while (t--) {
        getline(cin, line);
        stringstream ss(line);
        string token;
        string source;
        string standard = "c++20";
        string optimization = "None";
        vector<string> warnings;
        string output = "a.out";
        ss >> token;
        while (ss >> token) {
            if (token.rfind("-std=", 0) == 0) {
                standard = token.substr(5);
            } else if (token.rfind("-O", 0) == 0) {
                optimization = token.substr(1);
            } else if (token.rfind("-W", 0) == 0) {
                warnings.push_back(token.substr(1));
            } else if (token.rfind("-o", 0) == 0) {
                output = token.substr(2);
            } else {
                source = token;
            }
        }
        cout << source << '\n' << standard << '\n' << optimization << '\n';
        if (warnings.empty()) cout << "None\n";
        else {
            for (size_t i = 0; i < warnings.size(); ++i) {
                if (i) cout << ' ';
                cout << warnings[i];
            }
            cout << '\n';
        }
        cout << output << '\n';
    }
    return 0;
}
