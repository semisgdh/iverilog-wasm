
This directory contains configurations for the tests that exercise the iverilog
compiler with the vvp simulation engine. Each test file is actually a JSON
file that calls out the test type, names the source file, the gold file, any
command argument flags.

{
    "type"   : "normal",
    "source" : "macro_str_esc.v",
    "gold"   : "macro_str_esc"
}
