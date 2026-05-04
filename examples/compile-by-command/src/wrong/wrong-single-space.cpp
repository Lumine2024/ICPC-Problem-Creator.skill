#include <bits/stdc++.h>

using namespace std;

vector<string> broken_split(const string& line) {
    vector<string> tokens;
    string current;
    for (char ch : line) {
        if (ch == ' ') {
            tokens.push_back(current);
            current.clear();
        } else {
            current += ch;
        }
    }
    tokens.push_back(current);
    return tokens;
}

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    int t = 0;
    cin >> t;
    string line;
    getline(cin, line);
    while (t--) {
        getline(cin, line);
        vector<string> tokens = broken_split(line);
        string source;
        bool source_set = false;
        string standard = "c++17";
        string optimization = "None";
        vector<string> warnings;
        string output = "a.out";
        for (size_t i = 1; i < tokens.size(); ++i) {
            const string& token = tokens[i];
            if (token.rfind("-std=", 0) == 0) {
                standard = token.substr(5);
            } else if (token.rfind("-O", 0) == 0) {
                optimization = token.substr(1);
            } else if (token.rfind("-W", 0) == 0) {
                warnings.push_back(token.substr(1));
            } else if (token.rfind("-o", 0) == 0) {
                output = token.substr(2);
            } else if (!source_set) {
                source = token;
                source_set = true;
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
