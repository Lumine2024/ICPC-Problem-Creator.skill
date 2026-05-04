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

void require_condition(bool condition, const string& message) {
    if (!condition) {
        quitf(_fail, "%s", message.c_str());
    }
}

}  // namespace

int main(int argc, char* argv[]) {
    registerValidation(argc, argv);

    int t = inf.readInt(1, 2000, "T");
    inf.readEoln();

    for (int tc = 1; tc <= t; ++tc) {
        string line = inf.readLine();
        require_condition(!line.empty(), "empty command line");
        require_condition(static_cast<int>(line.size()) <= 200, "command line too long");
        for (char ch : line) {
            unsigned char value = static_cast<unsigned char>(ch);
            require_condition(32 <= value && value <= 126, "non-printable ascii found");
        }

        vector<string> tokens = split_tokens(line);
        require_condition(!tokens.empty(), "no tokens");
        require_condition(tokens[0] == "g++", "first token must be g++");

        int source_count = 0;
        int std_count = 0;
        int opt_count = 0;
        int out_count = 0;
        set<string> warning_set;

        for (size_t i = 1; i < tokens.size(); ++i) {
            const string& token = tokens[i];
            if (token.rfind("-std=", 0) == 0) {
                ++std_count;
                require_condition(static_cast<int>(token.size()) > 5, "empty std token");
            } else if (token.rfind("-O", 0) == 0) {
                ++opt_count;
                require_condition(static_cast<int>(token.size()) > 2, "empty optimization token");
            } else if (token.rfind("-W", 0) == 0) {
                require_condition(static_cast<int>(token.size()) > 2, "empty warning token");
                require_condition(warning_set.insert(token).second, "duplicate warning token");
            } else if (token.rfind("-o", 0) == 0) {
                ++out_count;
                require_condition(static_cast<int>(token.size()) > 2, "empty output token");
            } else {
                require_condition(token[0] != '-', "unknown flag token");
                ++source_count;
            }
        }

        require_condition(source_count == 1, "source token count must be 1");
        require_condition(std_count <= 1, "too many std tokens");
        require_condition(opt_count <= 1, "too many optimization tokens");
        require_condition(out_count <= 1, "too many output tokens");
    }

    inf.readEof();
    return 0;
}
