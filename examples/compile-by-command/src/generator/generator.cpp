#include "testlib.h"
#include <algorithm>
#include <iostream>
#include <string>
#include <vector>

using namespace std;

namespace {

const vector<string> kStandards = {
    "c++11", "c++14", "c++17", "c++20", "gnu++17", "gnu++20", "gnu++23", "^_^", "c++2b"
};

const vector<string> kOptimizations = {
    "O0", "O1", "O2", "O3", "Og", "Os", "Oz", "Ofast", "OlympicInformatics"
};

const vector<string> kWarnings = {
    "Wall", "Wextra", "Wshadow", "Wconversion", "Wformat=2", "Wundef",
    "Wdouble-promotion", "Wuseless-cast", "Wduplicated-cond", "Wnull-dereference",
    "Wl,--stack,1145141919810", "Winvalid-offsetof", "Wstack-usage=4096",
    "Wzero-as-null-pointer-constant", "Wimplicit-fallthrough", "Wformat-overflow=2"
};

string random_name(int min_len, int max_len, bool allow_dot) {
    const string letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_";
    const string with_dot = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.";
    int len = rnd.next(min_len, max_len);
    string result;
    result += letters[rnd.next(0, static_cast<int>(letters.size()) - 1)];
    const string& pool = allow_dot ? with_dot : letters;
    while (static_cast<int>(result.size()) < len) {
        result += pool[rnd.next(0, static_cast<int>(pool.size()) - 1)];
    }
    return result;
}

string render_command(const vector<string>& tokens, int leading_spaces, int trailing_spaces, int min_between, int max_between) {
    string line(leading_spaces, ' ');
    for (size_t i = 0; i < tokens.size(); ++i) {
        if (i > 0) {
            line.append(rnd.next(min_between, max_between), ' ');
        }
        line += tokens[i];
    }
    line.append(trailing_spaces, ' ');
    return line;
}

vector<string> build_tokens(bool include_std, bool include_opt, bool include_out, const vector<string>& warnings, bool source_has_dot) {
    vector<string> tokens = {"g++"};
    string source = random_name(1, 16, source_has_dot);
    if (source_has_dot && source.find('.') == string::npos) {
        source += ".cc";
    }
    vector<string> parts;
    parts.push_back(source);
    if (include_std) {
        parts.push_back("-std=" + kStandards[rnd.next(0, static_cast<int>(kStandards.size()) - 1)]);
    }
    if (include_opt) {
        parts.push_back("-" + kOptimizations[rnd.next(0, static_cast<int>(kOptimizations.size()) - 1)]);
    }
    for (const string& warning : warnings) {
        parts.push_back("-" + warning);
    }
    if (include_out) {
        parts.push_back("-o" + random_name(3, 18, true));
    }
    shuffle(parts.begin(), parts.end());
    for (const string& part : parts) {
        tokens.push_back(part);
    }
    return tokens;
}

string random_command(bool source_has_dot, int warning_count, bool force_spaces, bool force_long_line) {
    vector<string> shuffled_warnings = kWarnings;
    shuffle(shuffled_warnings.begin(), shuffled_warnings.end());
    int count = min(warning_count, static_cast<int>(shuffled_warnings.size()));

    int leading = force_spaces ? rnd.next(2, 7) : rnd.next(0, 2);
    int trailing = force_spaces ? rnd.next(2, 7) : rnd.next(0, 2);
    int min_between = force_spaces ? 2 : 1;
    int max_between = force_spaces ? 8 : 3;

    vector<string> tokens;
    string line;
    while (true) {
        vector<string> warnings(shuffled_warnings.begin(), shuffled_warnings.begin() + count);
        tokens = build_tokens(true, true, true, warnings, source_has_dot);
        line = render_command(tokens, leading, trailing, min_between, max_between);

        if (force_long_line && static_cast<int>(line.size()) < 170 && count < static_cast<int>(shuffled_warnings.size())) {
            ++count;
            continue;
        }
        if (static_cast<int>(line.size()) > 200) {
            if (count > 0) {
                --count;
                continue;
            }
            leading = 0;
            trailing = 0;
            min_between = 1;
            max_between = 1;
            line = render_command(tokens, leading, trailing, min_between, max_between);
        }
        break;
    }
    return line;
}

void output_case(const vector<string>& commands) {
    cout << commands.size() << '\n';
    for (const string& command : commands) {
        cout << command << '\n';
    }
}

vector<string> make_bulk_commands(int count, bool source_has_dot, bool heavy_spaces, bool long_lines) {
    vector<string> commands;
    commands.reserve(count);
    for (int i = 0; i < count; ++i) {
        int warning_count = long_lines ? rnd.next(6, 10) : rnd.next(0, 5);
        commands.push_back(random_command(source_has_dot || rnd.next(0, 1), warning_count, heavy_spaces && rnd.next(0, 3) != 0, long_lines));
    }
    return commands;
}

}  // namespace

int main(int argc, char* argv[]) {
    registerGen(argc, argv, 1);
    if (argc != 3) {
        cerr << "Usage: generator <type> <seed>\n";
        return 1;
    }

    string type = argv[1];
    long long seed = atoll(argv[2]);
    rnd.setSeed(seed);

    if (type == "sample") {
        output_case({
            "g++ foo.cc",
            "g++ -O2 -Wall -Wextra -std=c++11 foo.cc -owoshinailong.out",
            "g++ qaq.cpp -oqwq.exe -Ofast -std=gnu++23"
        });
    } else if (type == "defaults") {
        output_case({"g++ foo.cc", "g++ main.cpp", "g++ solver", "g++ code.cc"});
    } else if (type == "std-only") {
        output_case({"g++ -std=c++11 foo.cc", "g++ main -std=gnu++23", "g++ -std=^_^ source.cc"});
    } else if (type == "opt-only") {
        output_case({"g++ -O2 foo.cc", "g++ main -Ofast", "g++ -Og a.cc"});
    } else if (type == "out-only") {
        output_case({"g++ foo.cc -ofoo.out", "g++ -omain.exe main", "g++ src.cc -otarget.bin"});
    } else if (type == "warning-only") {
        output_case({"g++ -Wall foo.cc", "g++ main -Wextra -Wshadow", "g++ -Wl,--stack,1145141919810 run.cc"});
    } else if (type == "mixed-order") {
        output_case({
            "g++ -Wall foo.cc -O2 -std=c++20 -ofoo.out",
            "g++ -omain.exe -Wextra main -std=gnu++20 -Og",
            "g++ -Wshadow -std=c++14 src.cc -obin -Wconversion -O3"
        });
    } else if (type == "many-spaces") {
        output_case({
            "   g++    foo.cc   -std=c++20      -O2   -Wall   -ofoo.out    ",
            "g++          main      -Wextra      -Wshadow      ",
            "     g++      -Ofast         bar.cc        -obar.exe"
        });
    } else if (type == "source-no-dot") {
        output_case({
            "g++ solver -O2 -Wall -osolver.out",
            "g++ main -std=gnu++23",
            "g++ answer -Wextra -Ofast -oresult"
        });
    } else if (type == "warning-order") {
        output_case({
            "g++ foo.cc -Wshadow -Wall -Wextra -Wconversion",
            "g++ -Wduplicated-cond main.cc -Wformat=2 -Wundef",
            "g++ src -Wzero-as-null-pointer-constant -Wextra -Wshadow"
        });
    } else if (type == "warning-special") {
        output_case({
            "g++ a.cc -Wl,--stack,1145141919810 -Wall -O2",
            "g++ -Winvalid-offsetof main.cc -Wformat-overflow=2",
            "g++ src.cc -Wextra -Wstack-usage=4096 -obin"
        });
    } else if (type == "long-line") {
        output_case({
            random_command(true, 8, false, true),
            random_command(true, 9, false, true),
            random_command(true, 10, false, true)
        });
    } else if (type == "anti-empty-split") {
        output_case({
            "      g++          foo.cc          -Wall          -Wextra          -std=c++20          -ofoo.out          ",
            "   g++      main      -Ofast      -Wshadow      -Wconversion      ",
            "      g++          -std=gnu++23          solver.cc          "
        });
    } else if (type == "bulk-small") {
        output_case(make_bulk_commands(60, true, false, false));
    } else if (type == "bulk-medium") {
        output_case(make_bulk_commands(220, rnd.next(0, 1), true, false));
    } else if (type == "bulk-large") {
        output_case(make_bulk_commands(600, rnd.next(0, 1), true, true));
    } else if (type == "bulk-max") {
        output_case(make_bulk_commands(1000, rnd.next(0, 1), true, true));
    } else {
        cerr << "Unknown case type: " << type << '\n';
        return 2;
    }

    return 0;
}
