#include "testlib.h"
#include <bits/stdc++.h>

using namespace std;

static string makeToken(int minLen, int maxLen) {
    const string letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    int len = rnd.next(minLen, maxLen);
    string token;
    for (int i = 0; i < len; ++i) {
        token += letters[rnd.next(0, (int)letters.size() - 1)];
    }
    return token;
}

int main(int argc, char* argv[]) {
    registerGen(argc, argv, 1);
    if (argc != 3) {
        cerr << "Usage: generator <type> <seed>\n";
        return 1;
    }

    string type = argv[1];
    long long seed = atoll(argv[2]);
    rnd.setSeed(seed);

    vector<string> stdVersions = {"c++11", "c++14", "c++17", "c++20", "gnu++17", "gnu++20", "gnu++23"};
    vector<string> opts = {"O0", "O2", "O3", "Ofast"};
    vector<string> warnings = {"Wall", "Wextra", "Wpedantic", "Wconversion", "Wunused", "Wmain", "Wshadow"};
    vector<string> exts = {".cc", ".cpp", ".cxx", ".c++"};
    vector<string> outExts = {".out", ".exe", ".foo"};

    int t = 1;
    if (type == "sample") {
        cout << "3\n";
        cout << "g++ foo.cc\n";
        cout << "g++ -O2 -Wall -Wextra -std=c++11 foo.cc -owoshinailong.out\n";
        cout << "g++ qaq.cpp -oqwq.exe -Ofast -std=gnu++23\n";
        return 0;
    } else if (type == "min") {
        t = 1;
    } else if (type == "random-small") {
        t = rnd.next(2, 6);
    } else if (type == "random-large") {
        t = rnd.next(8, 16);
    } else if (type == "max") {
        t = 20;
    } else {
        cerr << "Unknown case type: " << type << '\n';
        return 2;
    }

    cout << t << '\n';
    for (int tc = 0; tc < t; ++tc) {
        vector<string> parts;
        parts.push_back("g++");
        if (type != "min" || tc > 0) {
            if (rnd.next(0, 1)) {
                parts.push_back("-std=" + rnd.any(stdVersions));
            }
            if (rnd.next(0, 1)) {
                parts.push_back("-" + rnd.any(opts));
            }
        }

        shuffle(warnings.begin(), warnings.end());
        int warnCount = (type == "max") ? min(4, (int)warnings.size()) : rnd.next(0, min(4, (int)warnings.size()));
        for (int i = 0; i < warnCount; ++i) {
            parts.push_back("-" + warnings[i]);
        }

        parts.push_back(makeToken(1, 16) + rnd.any(exts));
        if (type == "max" || rnd.next(0, 1)) {
            parts.push_back("-o" + makeToken(1, 16) + rnd.any(outExts));
        }

        int leadingSpaces = (type == "max") ? 4 : rnd.next(0, 3);
        int trailingSpaces = (type == "max") ? 3 : rnd.next(0, 2);
        cout << string(leadingSpaces, ' ');
        for (int i = 0; i < (int)parts.size(); ++i) {
            cout << parts[i];
            if (i + 1 != (int)parts.size()) {
                cout << string(rnd.next(1, 4), ' ');
            }
        }
        cout << string(trailingSpaces, ' ') << '\n';
    }
    return 0;
}
