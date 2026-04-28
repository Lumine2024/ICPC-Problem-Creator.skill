#include <bits/stdc++.h>

using namespace std;

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    int t = 0;
    cin >> t;
    cin.ignore(numeric_limits<streamsize>::max(), '\n');
    while (t--) {
        string line;
        getline(cin, line);
        stringstream ss(line);
        string token;
        string source;
        string standard = "c++20";
        string optimize = "None";
        string output = "a.out";
        vector<string> warnings;

        while (ss >> token) {
            if (token == "g++") continue;
            if (token[0] != '-') source = token;
            else if (token.size() > 5 && token.substr(0, 5) == "-std=") standard = token.substr(5);
            else if (token.size() > 2 && token[1] == 'O') optimize = token.substr(1);
            else if (token.size() > 2 && token[1] == 'W') warnings.push_back(token.substr(1));
            else if (token.size() > 2 && token[1] == 'o') output = token.substr(2);
        }

        cout << source << '\n' << standard << '\n' << optimize << '\n';
        if (warnings.empty()) cout << "None\n";
        else {
            for (int i = 0; i < (int)warnings.size(); ++i) {
                if (i) cout << ' ';
                cout << warnings[i];
            }
            cout << '\n';
        }
        cout << output << '\n';
    }
    return 0;
}
