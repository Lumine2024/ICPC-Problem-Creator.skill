#include "testlib.h"
#include <set>
#include <sstream>
#include <string>

using namespace std;

int main(int argc, char** argv) {
    registerValidation(argc, argv);

    int t = inf.readInt(1, 20, "T");
    inf.readEoln();
    for (int i = 1; i <= t; ++i) {
        setTestCase(i);
        string line = inf.readLine();
        ensuref(line.size() <= 200, "line %d is too long", i);
        for (unsigned char c : line) {
            ensuref(c < 0x80u, "non-ascii character on line %d", i);
        }

        stringstream ss(line);
        string token;
        ensuref(bool(ss >> token), "line %d is empty", i);
        ensuref(token == "g++", "line %d does not start with g++", i);

        set<string> seenWarnings;
        bool hasFile = false, hasStd = false, hasOpt = false, hasOutput = false;
        while (ss >> token) {
            if (token[0] != '-') {
                ensuref(!hasFile, "multiple source files on line %d", i);
                hasFile = true;
            } else if (token.size() > 5 && token.substr(0, 5) == "-std=") {
                ensuref(!hasStd, "multiple standards on line %d", i);
                hasStd = true;
            } else if (token.size() > 2 && token[1] == 'O') {
                ensuref(!hasOpt, "multiple optimization flags on line %d", i);
                hasOpt = true;
            } else if (token.size() > 2 && token[1] == 'W') {
                ensuref(!seenWarnings.count(token), "duplicate warning flag on line %d", i);
                seenWarnings.insert(token);
            } else if (token.size() > 2 && token[1] == 'o') {
                ensuref(!hasOutput, "multiple output flags on line %d", i);
                hasOutput = true;
            } else {
                ensuref(false, "unknown flag %s on line %d", token.c_str(), i);
            }
        }

        ensuref(hasFile, "missing source file on line %d", i);
    }

    inf.readEof();
    return 0;
}
