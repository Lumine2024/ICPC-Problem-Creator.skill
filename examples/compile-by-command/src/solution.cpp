#include <bits/stdc++.h>

using namespace std;

namespace {

vector<string> split_tokens(const string& line) {
    vector<string> tokens;
    string current;
    for (char ch : line) {
        if (ch == ' ') {
            if (!current.empty()) {
                tokens.push_back(current);
                current.clear();
            }
        } else {
            current += ch;
        }
    }
    if (!current.empty()) {
        tokens.push_back(current);
    }
    return tokens;
}

struct ParsedCommand {
    string source;
    string standard = "c++17";
    string optimization = "None";
    vector<string> warnings;
    string output = "a.out";
};

ParsedCommand parse_command(const string& line) {
    vector<string> tokens = split_tokens(line);
    ParsedCommand parsed;
    for (size_t i = 1; i < tokens.size(); ++i) {
        const string& token = tokens[i];
        if (token.rfind("-std=", 0) == 0) {
            parsed.standard = token.substr(5);
        } else if (token.rfind("-O", 0) == 0) {
            parsed.optimization = token.substr(1);
        } else if (token.rfind("-W", 0) == 0) {
            parsed.warnings.push_back(token.substr(1));
        } else if (token.rfind("-o", 0) == 0) {
            parsed.output = token.substr(2);
        } else {
            parsed.source = token;
        }
    }
    return parsed;
}

}  // namespace

int main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    int t = 0;
    cin >> t;
    string line;
    getline(cin, line);

    while (t--) {
        getline(cin, line);
        ParsedCommand parsed = parse_command(line);
        cout << parsed.source << '\n';
        cout << parsed.standard << '\n';
        cout << parsed.optimization << '\n';
        if (parsed.warnings.empty()) {
            cout << "None\n";
        } else {
            for (size_t i = 0; i < parsed.warnings.size(); ++i) {
                if (i > 0) {
                    cout << ' ';
                }
                cout << parsed.warnings[i];
            }
            cout << '\n';
        }
        cout << parsed.output << '\n';
    }
    return 0;
}
