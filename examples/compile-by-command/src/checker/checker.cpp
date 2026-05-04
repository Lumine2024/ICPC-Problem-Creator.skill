#include "testlib.h"
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

string join_tokens(const vector<string>& tokens) {
    string result;
    for (size_t i = 0; i < tokens.size(); ++i) {
        if (i > 0) {
            result += ' ';
        }
        result += tokens[i];
    }
    return result;
}

}  // namespace

int main(int argc, char* argv[]) {
    registerTestlibCmd(argc, argv);

    int t = inf.readInt();
    inf.readEoln();
    for (int i = 0; i < t; ++i) {
        inf.readLine();
    }
    inf.readEof();

    for (int i = 0; i < t; ++i) {
        for (int row = 0; row < 5; ++row) {
            vector<string> expected = split_tokens(ans.readLine());
            vector<string> actual = split_tokens(ouf.readLine());
            if (expected != actual) {
                quitf(
                    _wa,
                    "command %d line %d: expected [%s], found [%s]",
                    i + 1,
                    row + 1,
                    join_tokens(expected).c_str(),
                    join_tokens(actual).c_str()
                );
            }
        }
    }

    ans.readEof();
    ouf.readEof();
    quitf(_ok, "accepted");
}
