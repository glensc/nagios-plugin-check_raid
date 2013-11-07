# Reporting bugs, submitting Pull Requests

Bugs should be reported to [github issue tracker](https://github.com/glensc/nagios-plugin-check_raid/issues).

Before opening new issue, check that your problem is not already reported,
also before opening bugreport, check that the bug is not already fixed by testing with master branch.

As it's unlikely I have same hardware as you, not to mention same condition that is not handled,
I ask you to provide output of the commands the plugin runs.
What commands plugin runs, can be seen with `-d` option:

    DEBUG EXEC: /proc/mdstat at ./check_raid.pl line 345.
    DEBUG EXEC: /usr/local/bin/arcconf GETSTATUS 1 at ./check_raid.pl line 345.
    DEBUG EXEC: /usr/local/bin/arcconf GETCONFIG 1 AL at ./check_raid.pl line 345.

Capture each command output to a file:

    cat /proc/mdstat > mdstat.out
    /usr/local/bin/arcconf GETSTATUS 1 > arcconf-getstatus.out
    /usr/local/bin/arcconf GETCONFIG 1 AL > arcconf-getconfig.out

In this particular example, the space between `1` and `>` is important, because `1>` means different thing (tells shell to redirect fd no 1).

The redirection commands should provide no output, all should be directed to `.out` file.
If they do, it means the command produced output to `stderr` stream as well.
Depending on the output, it may make difference what that is,
usually those messages are small and can be included with bugreport.

The command output should be shared by some pastebin service, maybe even [gist](https://gists.github.com) because it may be important how the output is formatted, some invisible bytes may make the difference. You may include the output in github reports if you enclose the block between triple backticks:

    ```
    some output here...
    ```

When submitting patches, pull requests, do not write changelog or attempt to update version,
the changes may not be merged on codebase you created patch for
and it will just create annoying merge conflicts later.

Verify that your changes do not break existing tests. To run all tests, invoke:

    make test
    
You can run also individual test separately:

```
$ perl t/status.t 
1..20
ok 1 - default staus undef
ok 2 - set ok
...
ok 20 - set unknown
```
