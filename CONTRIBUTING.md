# Reporting bugs, submitting Pull Requests

## Reporting issues

Bugs should be reported to [issue tracker](https://github.com/glensc/nagios-plugin-check_raid/issues).

Before opening [new issue](https://github.com/glensc/nagios-plugin-check_raid/issues/new), first check that the bug is not already fixed by testing with master branch, then check that your problem is not already reported, by looking at [open issues](https://github.com/glensc/nagios-plugin-check_raid/issues?state=open).

In addition to problem description and perhaps proposed fix, please provide [debug output](#capture-debug-output-from-commands) from commands (include all command outputs, even if you think it is not neccessary), so that fixes and further development of the plugin will not cause configurations to fail.

It is very important that you **do provide** the command output, I can not support your usecase otherwise.

## Pull requests

- Fork it.
- Create your feature branch (`git checkout -b fixing-blah`), please avoid working directly on the `master` branch.
- [Test](#testing) your changes to the best of your ability.
- Check for unnecessary whitespace with `git diff --check` before committing.
- Commit your changes (`git commit -am 'Fixed blah'`).
- Push to the branch (`git push origin fixing-blah`).
- Create a new pull request.

Do not update changelog or attempt to change version, the changes may not be merged on codebase you created patch for and it will just create annoying merge conflicts later.

Also do consider adding [debug output](#capture-debug-output-from-commands) as part of the commit, including registering new test to get the changes tested.

## Capture debug output from commands

As it's unlikely I have same hardware as you, not to mention same condition that is not handled, I ask you to provide output of the commands the plugin runs.
What commands are ran by `check_raid`, can be seen with `-d` option:

    DEBUG EXEC: /proc/mdstat at ./check_raid.pl line 345.
    DEBUG EXEC: /usr/local/bin/arcconf GETSTATUS 1 at ./check_raid.pl line 345.
    DEBUG EXEC: /usr/local/bin/arcconf GETCONFIG 1 AL at ./check_raid.pl line 345.

Capture each command output to a file:

    cat /proc/mdstat > mdstat.out
    /usr/local/bin/arcconf GETSTATUS 1 > arcconf-getstatus.out
    /usr/local/bin/arcconf GETCONFIG 1 AL > arcconf-getconfig.out

*In this particular example, the space between `1` and `>` is important, because `1>` means different thing (tells shell to redirect fd no 1).*

The redirection commands should provide no output, all should be directed to `.out` file.
If they do, it means the command produced output to `stderr` stream as well.
Depending on the output, it may make difference what that is,
usually those messages are small and can be included into bug report.

After you have capture the output from the commands, you need to provide them to me.

To include the output to github ticket, enclose the block between triple backticks:

    ```
    some output here...
    ```

Alternatively post outputs to some pastebin service, or [gist](https://gists.github.com).
I recommend using [sprunge](http://sprunge.us/) due it's simple command line usage.

When referring to pastebin entries, do not forget to describe which command output the entry is. 

## Testing ##

When contributing changes back, the existing tests must pass, before and after your changes. Please note that new test data is not detected automatically, it must be registered in test files.

To run all tests, invoke:

    make test

To run each test separately:

```
$ perl t/status.t
1..20
ok 1 - default status undef
ok 2 - set ok
...
ok 20 - set unknown
```

To add new test data, save output of commands to `t/data/PLUGIN_NAME/IDENTIFIER` directory, filenames should be meaningful, like 'pr40' for Pull-Request #40. and add the new test with input files in `t/check_PLUGIN.t`.

(in github ticket and pull-request numbers are interchangeable).	
