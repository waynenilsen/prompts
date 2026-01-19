
the unit tests are currently failing

run them with bun run test to see the test failure

if there is a pattern - say 10 instances of something - work to get one test file or even a single test passing for the case in question before trying to fix all of them. this will decrease your cycle times and context usage.

once you have one test passing, you can then apply the same fix pattern to the remaining instances using subagents most likely is fine if it is across multiple files and its the same pattern of trouble

try your best to fix them

check for existing notes on the issue

if you cannot fix them add a note in the ./notes folder

filename format yyyy-mm-ddThh-mm-ss-kebab-case-description-of-things-tried.md

in this document you summarize what you tried, what you made progress with
what you tried that failed

if you did fix the tests then when you're done

format
lint fix
stage
commit with a good commit message using ./conventional-commits.md
and push